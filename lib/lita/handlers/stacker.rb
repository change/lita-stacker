# frozen_string_literal: true

require 'active_support/core_ext/array/conversions' # Array.to_sentence, for i18n

module Lita
  module Handlers
    class Stacker < Handler
      VERSION = '1.0.0'

      config :timeout, type: Integer, default: 8 * 60 * 60 # 8.hours

      route(/^stack(\s+(on.*|\@\p{Word}+\s*))?$/, :lifo_add, help: {
              t('add.help.simple.command') => t('add.help.simple.description'),
              t('add.help.on.command') => t('add.help.on.description'),
              t('add.help.another.command') => t('add.help.another.description')
            })
      route(/^(unstack|stack (drop|done))(\s+\@\p{Word}+\s*)?$/, :lifo_remove, help: {
              t('remove.help.unstack.command') => t('remove.help.unstack.description'),
              t('remove.help.done.command') => t('remove.help.done.description'),
              t('remove.help.drop.command') => t('remove.help.drop.description')
            })
      route(/^restack(\s+\@\p{Word}+\s*)?$/, :lifo_requeue, help: {
              t('remove.help.restack.command') => t('remove.help.restack.description')
            })
      route(/^stacks? (show|list)/, :lifo_peek, help: {
              t('peek.help.show.singular.command') => t('peek.help.show.singular.description'),
              t('peek.help.show.plural.command') => t('peek.help.show.plural.description'),
              t('peek.help.list.singular.command') => t('peek.help.list.singular.description'),
              t('peek.help.list.plural.command') => t('peek.help.list.plural.description')
            })
      route(/^stacks? clear/, :lifo_clear, help: {
              t('clear.help.singular.command') => t('clear.help.singular.description'),
              t('clear.help.plural.command') => t('clear.help.plural.description')
            })

      def lifo_add(response)
        return if incompatible?(response)

        user_to_add = pick_subject(response)

        clean_stack(response.message.source.room)
        score = redis.zscore(response.message.source.room, user_to_add)

        return add_collision(response, user_to_add, score, response.message.source.room) if score

        add_without_collision(response, user_to_add, response.message.source.room)
      end

      def lifo_peek(response)
        return if incompatible?(response)

        clean_stack(response.message.source.room)
        contents = redis.zrangebyscore(response.message.source.room, '-inf', '+inf')

        if contents.empty?
          response.reply(t('peek.empty'))
          return
        end

        text_list = contents.each_with_index.map { |item, idx| "#{idx + 1}. @#{item}" }.join("\n")
        response.reply(t('peek.list', newline_separated_list: text_list))
      end

      def lifo_remove(response)
        return if incompatible?(response)

        to_remove = pick_subject(response)

        # Simulate ZPOPMIN, which is only available starting in Redis 5.
        script = <<~LUA
          local rank = redis.call('zrank', KEYS[1], ARGV[1])
          redis.call('zrem', KEYS[1], ARGV[1])

          if (rank ~= 0) then
            return nil
          end

          return redis.call('zrange', KEYS[1], 0, 0)[1]
        LUA

        clean_stack(response.message.source.room)
        next_user = redis.eval(script, [response.message.source.room], [to_remove])

        to_remove = "@#{to_remove}"

        if next_user
          response.reply(t('remove.complete.first', user: to_remove, next_user: "@#{next_user}"))
        else
          response.reply(t('remove.complete.other', user: to_remove))
        end
      end

      def lifo_requeue(response)
        lifo_remove(response)
        lifo_add(response)
      end

      def lifo_clear(response)
        return if incompatible?(response)
        redis.del(response.message.source.room)
        response.reply(t('clear.complete', user: "@#{response.user.mention_name}"))
      end

      private

      def after_list(list)
        list.map { |x| "@#{x}" }.to_sentence
      end

      def clean_stack(stack)
        redis.zremrangebyscore(stack, 0, Time.now.to_f - config.timeout)
      end

      def incompatible?(response)
        response.message.source.private_message?
      end

      def pick_subject(response)
        subject = response.user.mention_name.tr('@', '')
        if response.message.args[0]
          arg = response.message.args[0].dup
          subject = arg if arg.tr!('@', '')
        end
        subject
      end

      def add_without_collision(response, user_to_add, room)
        script = <<~LUA
          local predecessors = redis.call('zrangebyscore', KEYS[1], '-inf', '+inf')
          redis.call('zadd', KEYS[1], ARGV[2], ARGV[1])
          return predecessors
        LUA

        result = redis.eval(script, [room], [user_to_add, Time.now.to_f])

        if result.empty?
          response.reply(t('add.first', user: "@#{user_to_add}"))
        else
          response.reply(t('add.after', user: "@#{user_to_add}", after: after_list(result)))
        end
      end

      def add_collision(response, user_to_add, score, room)
        predecessors = redis.zrevrangebyscore(room, "(#{score}", 0)
        type = predecessors.empty? ? 'first' : 'after'
        response.reply(t("add.collision.#{type}", user: "@#{user_to_add}", after: after_list(predecessors)))
      end
    end

    Lita.register_handler(Stacker)
  end
end
