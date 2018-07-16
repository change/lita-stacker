# frozen_string_literal: true

module Lita
  module Handlers
    class Stacker < Handler
      route(/^stack(\s+\@\p{Word}+\s*)?$/, :lifo_add)
      route(/^unstack(\s+\@\p{Word}+\s*)?$/, :lifo_remove)
      route(/^stack drop/, :lifo_remove)
      route(/^stack show/, :lifo_peek)
      route(/^stack clear/, :lifo_clear)

      def lifo_add(response)
        return if is_incompatible?(response)

        redis.rpush(response.message.source.room, pick_subject(response))
      end

      def lifo_peek(response)
        return if is_incompatible?(response)
        contents = redis.lrange(response.message.source.room, 0, -1)

        if contents.empty?
          response.reply('The stack is empty.')
          return
        end

        text_list = contents.each_with_index.map { |item, idx| "#{idx + 1}. #{item}" }.join("\n")
        response.reply("Stack list:\n#{text_list}")
      end

      def lifo_remove(response)
        return if is_incompatible?(response)

        to_remove = pick_subject(response)
        redis.lrem(response.message.source.room, 0, to_remove)
        response.reply("@#{to_remove} gone from stack.")
      end

      def lifo_clear(response)
        return if is_incompatible?(response)
        redis.del(response.message.source.room)
        response.reply("Stacks cleared by @#{response.user.mention_name}")
      end

      private

      def is_incompatible?(response)
        response.message.source.private_message?
      end

      def pick_subject(response)
        (response.message.args[0] || response.user.mention_name).tr('@', '')
      end
    end

    Lita.register_handler(Stacker)
  end
end
