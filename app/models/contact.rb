# frozen_string_literal: true

#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class Contact < ApplicationRecord
  include Diaspora::Federated::Base

  # The Contact class represents a relationship between a user and a person.
  # It serves as an aggregate root for managing contact-related business logic.


  belongs_to :user # Represents the user that owns this contact.
  belongs_to :person # Represents the person being contacted.

  
  # Delegates to the person model, which keeps the Contact model clean.
  # Consider whether this should be a value object for clearer intent.
  validates :person_id, uniqueness: {scope: :user_id} # Ensure a user can't have multiple contacts for the same person.

  delegate :name, :diaspora_handle, :guid, :first_name,
           to: :person, prefix: true

  has_many :aspect_memberships, dependent: :destroy # Relationships to user aspects.
  has_many :aspects, through: :aspect_memberships # Allows access to aspects through memberships.

  # Business logic validations that ensure proper relationships.

  validate :not_contact_for_self,
           :not_blocked_user,
           :not_contact_with_closed_account

  before_destroy :destroy_notifications # Clean up notifications related to this contact.

  # Scope for retrieving all contacts of a specific person.
  scope :all_contacts_of_person, ->(x) { where(person_id: x.id) }

  # Scopes to filter contacts based on sharing and receiving states.
  # contact.sharing is true when contact.person is sharing with contact.user
  scope :sharing, -> { where(sharing: true) }

  # contact.receiving is true when contact.user is sharing with contact.person
  scope :receiving, -> { where(receiving: true) }

  scope :mutual, -> { sharing.receiving } # Contacts that are both sharing and receiving.

  scope :for_a_stream, -> { includes(:aspects, person: :profile).order("profiles.last_name ASC") }

  scope :only_sharing, -> { sharing.where(receiving: false) }

  # Method to clean up notifications when a contact is destroyed.
  def destroy_notifications
    # This creates a direct dependency on the Notification class, which could be abstracted.
    Notification.where(
      target_type:  "Person",
      target_id:    person_id,
      recipient_id: user_id,
      type:         "Notifications::StartedSharing"
    ).destroy_all
  end

  # Check if the contact is mutual (both sharing and receiving).
  def mutual?
    sharing && receiving
  end

  # Check if the contact belongs to a specific aspect.
  def in_aspect?(aspect)
    if aspect_memberships.loaded?
       # This method should leverage lazy loading for efficiency.
      aspect_memberships.detect{ |am| am.aspect_id == aspect.id }
    elsif aspects.loaded?
      aspects.detect{ |a| a.id == aspect.id }
    else
      AspectMembership.exists?(:contact_id => self.id, :aspect_id => aspect.id)
    end
  end

  # Follows back if user setting is set so
  def receive(_recipient_user_ids)
    # Consider extracting this logic to a domain service to maintain clean separation.
    user.share_with(person, user.auto_follow_back_aspect) if user.auto_follow_back && !receiving
  end

  # Returns the recipient of the contact.
  # This could be expanded into a more complex domain model if needed.
  def object_to_receive
    Contact.create_or_update_sharing_contact(person.owner, user.person)
  end

  # @return [Array<Person>] The recipient of the contact
  def subscribers
    [person]
  end

  # creates or updates a contact with active sharing flag. Returns nil if already sharing.
  # It would be better to extract this method into a dedicated service for better separation of concerns.
  def self.create_or_update_sharing_contact(recipient, sender)
    contact = recipient.contacts.find_or_initialize_by(person_id: sender.id)

    return if contact.sharing # Early return if already sharing.

    contact.update(sharing: true) # Update the contact to reflect sharing status.
    contact
  end

  private

  def not_contact_with_closed_account
    errors.add(:base, "Cannot be in contact with a closed account") if person_id && person.closed_account?
  end

   # Validation to prevent self-contacts.
  def not_contact_for_self
    errors.add(:base, "Cannot create self-contact") if person_id && person.owner == user
  end
  

  # Validation to prevent connecting with blocked users.
  def not_blocked_user
    if receiving && user && user.blocks.where(person_id: person_id).exists?
      errors.add(:base, "Cannot connect to an ignored user")
    end
  end
end
