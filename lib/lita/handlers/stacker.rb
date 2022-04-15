# frozen_string_literal: true

module Lita
  module Handlers
    class Stacker < Handler
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

        unless user_to_add
          response.reply(t('add.not_found', user: "@#{pick_subject_name(response)}"))
          return
        end

        (result, announce_floor) = perform_add(response.message.source.room, user_to_add)

        if result.empty?
          response.reply(t('add.first', user: subject_name(user_to_add)))
        else
          # Special case: head of the stack changed, the floor may have changed.
          response.reply(t('add.first', user: subject_name(result.first))) if announce_floor
          response.reply(t('add.after', user: subject_name(user_to_add), after: after_list(result)))
        end
      end

      def lifo_peek(response)
        return if incompatible?(response)

        room = response.message.source.room

        clean_stack(room)
        contents = redis.zrangebyscore(room, '-inf', '+inf')

        if contents.empty?
          response.reply(t('peek.empty'))
          return
        end

        text_list = contents.each_with_index.map { |item, idx| "#{idx + 1}. #{subject_name(item)}" }.join("\n")
        response.reply(t('peek.list', newline_separated_list: text_list))
      end

      def lifo_remove(response)
        return if incompatible?(response)

        to_remove = pick_subject(response)

        unless to_remove
          result.reply(t('remove.not_found', user: "@#{pick_subject_name(response)}"))
          return
        end

        next_user = perform_remove(response.message.source.room, to_remove)

        if next_user
          response.reply(t('remove.complete.first', user: subject_name(to_remove), next_user: subject_name(next_user)))
        else
          response.reply(t('remove.complete.other', user: subject_name(to_remove)))
        end
      end

      def lifo_clear(response)
        return if incompatible?(response)
        redis.del(response.message.source.room)
        response.reply(t('clear.complete', user: "@#{response.user.mention_name}"))
      end

      private

      def perform_add(room, user)
        clean_stack(room)

        # Special case: user is at the top of the stack:
        announce_floor = redis.zrank(room, user.id)&.zero?

        script = <<~LUA
          local predecessors = redis.call('zrangebyscore', KEYS[1], '-inf', '+inf')
          redis.call('zadd', KEYS[1], ARGV[2], ARGV[1])
          return predecessors
        LUA

        result = redis.eval(script, [room], [user.id, Time.now.to_f])
        result.delete(user.id)
        [result, announce_floor]
      end

      def perform_remove(room, user)
        clean_stack(room)

        # Simulate ZPOPMIN, which is only available starting in Redis 5.
        script = <<~LUA
          local rank = redis.call('zrank', KEYS[1], ARGV[1])
          redis.call('zrem', KEYS[1], ARGV[1])

          if (rank ~= 0) then
            return nil
          end

          return redis.call('zrange', KEYS[1], 0, 0)[1]
        LUA

        redis.eval(script, [room], [user.id])
      end

      def subject_name(user)
        mention = if user.respond_to?(:mention_name)
                    user.mention_name || user.name
                  else
                    Lita::User.find_by_id(user)&.mention_name
                  end

        if mention
          mention.sub(/^@?/, '@')
        else
          "<#{user}>"
        end
      end

      def after_list(list)
        # This require cannot be at the top level, or the gemspec cannot be
        # loaded without it already being present, which prevents the
        # dependency being asserted.
        require 'active_support/core_ext/array/conversions'
        list.map { |u| subject_name(u) }.to_sentence
      end

      def clean_stack(stack)
        redis.zremrangebyscore(stack, 0, Time.now.to_f - config.timeout)
      end

      def incompatible?(response)
        response.message.source.private_message?
      end

      def pick_subject(response)
        subject = pick_subject_name(response)
        Lita::User.find_by_mention_name(subject) || Lita::User.find_by_name(subject)
      end

      def pick_subject_name(response)
        subject = response.user.mention_name.tr('@', '')
        if response.message.args[0]
          arg = response.message.args[0].dup
          subject = arg if arg.tr!('@', '')
        end
        subject
      end
    end

    Lita.register_handler(Stacker)
  end
end
