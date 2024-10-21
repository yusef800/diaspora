# frozen_string_literal: true

#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class Service < ApplicationRecord
  attr_accessor :provider, :info, :access_level # Temporary attributes that do not persist in the database.

  belongs_to :user # Indicates that each service is associated with a user.

  # DDD Concern: Consider whether the uniqueness validation on :uid and :type accurately reflects the domain rules.
  validates_uniqueness_of :uid, :scope => :type

  def profile_photo_url
    nil # Placeholder method, should be overridden by subclasses to provide actual URLs.
  end

  def post_opts(post)
    # don't do anything (should be overridden by service extensions)
    # This method is a no-op and should be overridden by service extensions.
    # DDD Suggestion: Consider using a strategy pattern to encapsulate posting logic based on the service type.
  end

  class << self
    # DDD Principle: Methods for handling service titles should ideally belong to a dedicated value object for clarity.
    def titles(service_strings)
      service_strings.map {|s| "Services::#{s.titleize}"}
    end

    def first_from_omniauth( auth_hash )
      @@auth = auth_hash # Directly assigning to a class variable can lead to issues in a multi-threaded environment.
      find_by(type: service_type, uid: options[:uid])
    end

    def initialize_from_omniauth( auth_hash )
      @@auth = auth_hash # Same concern as above regarding class variable usage.
      service_type.constantize.new( options )
    end

    def auth
      @@auth # Class variable usage raises thread-safety concerns and can lead to unexpected behavior.
    end

    def service_type
      "Services::#{options[:provider].camelize}" # Constructs the service type from provider info.
    end

    def options
      {
        nickname:      auth['info']['nickname'],
        access_token:  auth['credentials']['token'],
        access_secret: auth['credentials']['secret'],
        uid:           auth['uid'],
        provider:      auth['provider'],
        info:          auth['info']
      }
    end

    private :auth, :service_type, :options
  end
end
