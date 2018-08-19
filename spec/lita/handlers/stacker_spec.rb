# frozen_string_literal: true

RSpec.describe Lita::Handlers::Stacker, lita_handler: true do
  let(:arthur) { Lita::User.create(42, name: 'Arthur', mention_name: 'dent') }
  let(:ford) { Lita::User.create(23, name: 'Ford', mention_name: 'prefect') }
  let(:marvin) { Lita::User.create(-1, name: 'marvin', mention_name: 'marvin') }
  let(:trillian) { Lita::User.create(456, name: 'Tricia MacMillian', mention_name: 'trillian') }
  let(:zaphod) { Lita::User.create(123, name: 'Zaphod', mention_name: 'beeblebrox') }

  it { is_expected.to route_command('stack').to(:lifo_add) }
  it { is_expected.to route_command('stack @user').to(:lifo_add) }
  it { is_expected.to route_command('stack on that').to(:lifo_add) }
  it { is_expected.not_to route_command('stack some boxes').to(:lifo_add) }
  it { is_expected.to route_command('unstack').to(:lifo_remove) }
  it { is_expected.to route_command('unstack @user').to(:lifo_remove) }
  it { is_expected.to route_command('stack drop').to(:lifo_remove) }
  it { is_expected.to route_command('stack done').to(:lifo_remove) }
  it { is_expected.to route_command('stack show').to(:lifo_peek) }
  it { is_expected.to route_command('stacks show').to(:lifo_peek) }
  it { is_expected.to route_command('stack clear').to(:lifo_clear) }
  it { is_expected.to route_command('stacks clear').to(:lifo_clear) }

  shared_examples 'a private chat' do
    let(:command_options) { {} }

    before do
      send_command(command, command_options)
    end

    it 'does nothing' do
      expect(replies).to be_empty
    end
  end

  shared_context 'in a room' do # rubocop:disable RSpec/ContextWording # clumsy otherwise
    let(:channel) { Lita::Room.create_or_update('#public_channel') }
    let(:command_options) { { from: channel } }
  end

  shared_examples 'it clears old stacks' do
    before do
      subject.redis.zadd(channel.name, Time.now.to_f - 3 * subject.config.timeout, trillian.id)
      subject.redis.zadd(channel.name, Time.now.to_f - 2 * subject.config.timeout, marvin.id)
    end

    it 'clears old stacks' do
      send_command(command, command_options)
      expect(subject.redis.zrangebyscore(channel.name, '-inf', '+inf') & [trillian.id, marvin.id]).to be_empty
    end
  end

  describe '#lifo_add' do
    let(:existing_stack) { [] }

    before do
      existing_stack.each { |u| send_command("stack @#{u.mention_name}", command_options) }
      send_command(command, command_options)
    end

    shared_examples 'adding users' do
      it_behaves_like 'a private chat'

      context 'when the message is in a room' do
        include_context 'in a room'

        it_behaves_like 'it clears old stacks'

        it 'informs the user they have the floor' do
          expect(replies.last).to include 'have the floor'
        end

        it 'adds the current user' do
          send_command 'stack show', command_options
          expect(replies.last).to include(target_user.mention_name)
        end

        context 'when there is a stack' do
          let(:existing_stack) { [trillian] }

          it 'informs the user who is before them' do
            expect(replies.last).to include "after @#{existing_stack.last.mention_name}"
          end

          it 'adds the user' do
            send_command 'stack show', command_options
            expect(replies.last).to include(target_user.mention_name)
          end

          context 'when the stack has more than 2 entries' do
            let(:existing_stack) { [trillian, ford, arthur, marvin] }

            it 'announces the whole list' do
              expect(replies.last).to match Regexp.new existing_stack.map(&:mention_name).join('.*')
            end
          end
        end

        context 'when the user is already in the stack' do
          let(:existing_stack) { [trillian] }

          before do
            send_command(command, command_options)
          end

          it 'informs the user' do
            expect(replies.last).to match(/after @#{existing_stack.last.mention_name}/)
          end

          it 'does not include the user in the list of predecessors' do
            expect(replies.last).not_to match(/after.*#{target_user.mention_name}/)
          end

          it 'does not add an additional the stack' do
            send_command 'stack show', command_options
            expect(replies.last.scan(/^\d+\.\s*@?#{target_user.mention_name}/).count).to eq 1
          end

          it 'moves them to the bottom' do
            send_command 'stack show', command_options
            expect(replies.last).to end_with target_user.mention_name
          end
        end
      end
    end

    context 'with an empty command' do
      let(:command) { 'stack' }

      include_examples 'adding users' do
        let(:target_user) { user }
      end
    end

    context 'with another user name' do
      let(:target_user) { zaphod }
      let(:command) { "stack @#{target_user.mention_name}" }

      include_examples 'adding users'
    end

    context 'with an on command' do
      let(:command) { 'stack on that' } # perhaps this should jump to the top?

      include_examples 'adding users' do
        let(:target_user) { user }
      end
    end

    context 'with a non-matching command' do
      let(:command) { 'stack some boxes' }

      it_behaves_like 'a private chat'

      context 'when the message is in a room' do
        include_context 'in a room'

        it 'does not add the current user' do
          send_command 'stack show', command_options
          expect(replies.last).to eq('The stack is empty!')
        end
      end
    end
  end

  describe '#lifo_peek' do
    let(:command) { 'stack show' }

    it_behaves_like 'a private chat'

    context 'when the message is in a room' do
      include_context 'in a room'

      it_behaves_like 'it clears old stacks'

      context 'when the stack is empty' do
        it 'informs the user' do
          send_command(command, command_options)
          expect(replies.last).to include 'empty'
        end
      end

      context 'when the stack is not empty' do
        before do
          send_command('stack', command_options)
        end

        it 'lists the users' do
          send_command(command, command_options)
          expect(replies.last).to match(/\d+\. @?#{user.mention_name.tr('@', '')}/)
        end
      end
    end
  end

  describe '#lifo_remove' do
    let(:command) { 'unstack' }

    it_behaves_like 'a private chat'

    context 'when the message is in a room' do
      include_context 'in a room'

      let(:other_user) { zaphod }

      it_behaves_like 'it clears old stacks'

      before do
        send_command('stack', command_options)
        send_command("stack @#{other_user.mention_name}", command_options)
      end

      context 'when the the top of the stack unstacks' do
        it 'announces the next user' do
          send_command('unstack', command_options)
          expect(replies.last).to include other_user.mention_name
        end
      end

      context 'when the another user unstacks' do
        it 'does not announce the first user' do
          send_command("unstack @#{other_user.mention_name}", command_options)
          expect(replies.last).not_to include user.mention_name
        end
      end
    end
  end

  describe '#lifo_clear' do
    let(:command) { 'stack clear' }

    it_behaves_like 'a private chat'

    context 'when the message is in a room' do
      include_context 'in a room'

      it 'informs the user' do
        send_command(command, command_options)
        expect(replies.last).to include "cleared by @#{user.mention_name}"
      end
    end
  end
end
