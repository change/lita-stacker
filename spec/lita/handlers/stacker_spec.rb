# frozen_string_literal: true

require 'spec_helper'

describe Lita::Handlers::Stacker, lita_handler: true do
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

  shared_context 'in a room' do
    let(:command_options) { { from: Lita::Room.create_or_update('#public_channel') } }
  end

  shared_context 'in a private chat' do
    let(:command_options) { {} }
  end

  describe '#lifo_add' do
    before do
      send_command(command, command_options)
      send_command 'stack show', command_options
    end

    context 'with an empty command' do
      let(:command) { 'stack' }

      context 'when the message is private' do
        include_context 'in a private chat'


        it 'does nothing' do
          expect(replies).to be_empty
        end
      end

      context 'when the message is in a room' do
        include_context 'in a room'

        it 'adds the current user' do
          expect(replies.last).to include(user.name)
        end
      end
    end

    context 'with another user name' do
      let(:other_user) { Lita::User.create(123, name: 'Zaphod') }
      let(:command) { "stack @#{other_user.name}" }

      context 'when the message is private' do
        include_context 'in a private chat'


        it 'does nothing' do
          expect(replies).to be_empty
        end
      end

      context 'when the message is in a room' do
        include_context 'in a room'

        it 'adds the specified user' do
          expect(replies.last).to include(other_user.name)
        end
      end
    end

    context 'with an on command' do
      let(:command) { 'stack on that' } # perhaps this should jump to the top?

      context 'when the message is private' do
        include_context 'in a private chat'


        it 'does nothing' do
          expect(replies).to be_empty
        end
      end

      context 'when the message is in a room' do
        include_context 'in a room'

        it 'adds the current user' do
          expect(replies.last).to include(user.name)
        end
      end
    end

    context 'with a non-matching command' do
      let(:command) { 'stack some boxes' }

      context 'when the message is in a room' do
        include_context 'in a room'

        it 'adds the current user' do
          expect(replies.last).to eq('The stack is empty.')
        end
      end
    end
  end
end
