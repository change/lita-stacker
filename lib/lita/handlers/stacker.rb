module Lita
  module Handlers
    class Stacker < Handler
      route %r{^stack$}, :lifo_add
      route %r{^unstack$}, :lifo_remove
      route %r{^stack drop}, :lifo_remove
      route %r{^stack show}, :lifo_peek
      route %r{^stack clear}, :lifo_clear

      def lifo_add(response)
        return if is_incompatible?(response)
        redis.rpush(response.message.source.room, response.user.name)
      end

      def lifo_peek(response)
        return if is_incompatible?(response)
        contents = redis.lrange(response.message.source.room, 0, -1)

        if contents.empty?
          response.reply("The stack is empty.")
          return
        end

        text_list = contents.each_with_index.map { |item, idx| "#{idx + 1}. #{item}" }.join("\n")
        response.reply("Stack list:\n#{text_list}")
      end

      def lifo_remove(response)
        return if is_incompatible?(response)
        redis.lrem(response.message.source.room, 0, response.user.name)
        response.reply("@#{response.user.mention_name} left the stack.")
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
    end

    Lita.register_handler(Stacker)
  end
end
