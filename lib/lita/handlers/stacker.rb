# frozen_string_literal: true

module Lita
  module Handlers
    class Stacker < Handler
      VERSION = '0.2.0'

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
      route(/^stacks? show/, :lifo_peek, help: {
              t('peek.help.singular.command') => t('peek.help.singular.description'),
              t('peek.help.plural.command') => t('peek.help.plural.description')
            })
      route(/^stacks? clear/, :lifo_clear, help: {
              t('clear.help.singular.command') => t('clear.help.singular.description'),
              t('clear.help.plural.command') => t('clear.help.plural.description')
            })

      def lifo_add(response)
        return if incompatible?(response)

        # There is no LSCAN Redis command, so we can hack one.
        # I am pretty sure Lita is synchronous so it is not possible for this
        # to be inconsistent. But in the iterest of robustness, run it as a
        # Lua script, to keep it atomic.
        script = <<~LUA
          for i=0,(redis.call('llen', KEYS[1])-1) do
            if (redis.call('lindex', KEYS[1], i) == ARGV[1]) then
              return -1
            end
          end
          redis.call('rpush', KEYS[1], ARGV[1])
          return redis.call('lindex', KEYS[1], -2)
        LUA

        user_to_add = pick_subject(response)

        result = redis.eval(script, [response.message.source.room], [user_to_add])

        if result == -1
          response.reply(t('add.collision'))
          return
        end

        if result
          response.reply(t('add.after', after: "@#{result}"))
        else
          response.reply(t('add.first', user: "@#{user_to_add}"))
        end
      end

      def lifo_peek(response)
        return if incompatible?(response)
        contents = redis.lrange(response.message.source.room, 0, -1)

        if contents.empty?
          response.reply(t('peek.empty'))
          return
        end

        text_list = contents.each_with_index.map { |item, idx| "#{idx + 1}. #{item}" }.join("\n")
        response.reply(t('peek.list', newline_separated_list: text_list))
      end

      def lifo_remove(response)
        return if incompatible?(response)

        to_remove = pick_subject(response)

        script = <<~LUA
          local first = redis.call('lindex', KEYS[1], 0) == ARGV[1]
          redis.call('lrem', KEYS[1], 0, ARGV[1])
          if first then
            return redis.call('lindex', KEYS[1], 0)
          end
          return first
        LUA

        next_user = redis.eval(script, [response.message.source.room], [to_remove])

        to_remove = "@#{to_remove}"

        if next_user
          response.reply(t('remove.complete.first', user: to_remove, next_user: "@#{next_user}"))
        else
          response.reply(t('remove.complete.other', user: to_remove))
        end
      end

      def lifo_clear(response)
        return if incompatible?(response)
        redis.del(response.message.source.room)
        response.reply(t('clear.complete', user: response.user.mention_name))
      end

      private

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
    end

    Lita.register_handler(Stacker)
  end
end
