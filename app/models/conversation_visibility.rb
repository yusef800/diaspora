# frozen_string_literal: true

class ConversationVisibility < ApplicationRecord
  belongs_to :conversation
  belongs_to :person
  after_destroy :check_orphan_conversation

  private

  # Destroy a conversation if there is no one participating in it
  def check_orphan_conversation
    conversation = Conversation.find_by_id(self.conversation.id)
    if conversation
      conversation.destroy if conversation.participants.count == 0
    end
  end
end
