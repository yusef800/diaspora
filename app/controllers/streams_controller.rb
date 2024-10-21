# frozen_string_literal: true

#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class StreamsController < ApplicationController
  # Ensures the user is authenticated, except for the `public` action.
  before_action :authenticate_user!, except: :public

  # Saves selected aspects to the session when accessing the `aspects` stream.
  before_action :save_selected_aspects, only: :aspects

  # Dynamically chooses layout based on the request format (mobile vs. desktop).
  layout proc { request.format == :mobile ? "application" : "with_header" }

  # Specifies response formats supported by this controller.
  respond_to :html, 
             :mobile,
             :json

  # ------------------
  # ACTION METHODS
  # ------------------

  # Fetches posts based on the selected aspects (user-defined groups).
  def aspects
    aspect_ids = (session[:a_ids] || [])
    @stream = Stream::Aspect.new(current_user, aspect_ids,
                                 :max_time => max_time)
    stream_responder
  end

  # Shows public posts available to all users.
  def public
    stream_responder(Stream::Public)
  end

  # Displays public posts only from the local pod (if configured).
  def local_public
    if AppConfig.local_posts_stream?(current_user)
      stream_responder(Stream::LocalPublic)
    else
      head :not_found # Returns a 404 status if not available.
    end
  end

  # Shows the user’s activity stream (recent actions or notifications).
  def activity
    stream_responder(Stream::Activity)
  end

  # Displays multiple streams simultaneously, often during the onboarding process.
  def multi
    # If the user is in the onboarding state, preload getting started content.
    if current_user.getting_started
      gon.preloads[:getting_started] = true

      # Preload inviter details if the user was invited by someone.
      inviter = current_user.invited_by.try(:person)
      gon.preloads[:mentioned_person] = {name: inviter.name, handle: inviter.diaspora_handle} if inviter
    end

    stream_responder(Stream::Multi)
  end

  # Displays posts where the user has commented.
  def commented
    stream_responder(Stream::Comments)
  end

  # Shows posts liked by the user.
  def liked
    stream_responder(Stream::Likes)
  end

  # Displays posts where the user was mentioned.
  def mentioned
    stream_responder(Stream::Mention)
  end

  # Displays posts related to tags followed by the user.
  def followed_tags
    gon.preloads[:tagFollowings] = tags # Preload followed tags data for the frontend.
    stream_responder(Stream::FollowedTag)
  end

  # ------------------
  # PRIVATE METHODS
  # ------------------
  private

  # Handles rendering and responding to different formats (HTML, mobile, JSON).
  def stream_responder(stream_klass=nil)

    if stream_klass.present?
      @stream ||= stream_klass.new(current_user, :max_time => max_time)
    end
    # Respond to the request based on its format.
    respond_with do |format|
      format.html { render 'streams/main_stream' }
      format.mobile { render 'streams/main_stream' }
      format.json { render :json => @stream.stream_posts.map {|p| LastThreeCommentsDecorator.new(PostPresenter.new(p, current_user)) }}
    end
  end

  # Saves selected aspect IDs to the session.
  def save_selected_aspects
    if params[:a_ids].present?
      session[:a_ids] = params[:a_ids]
    end
  end
end
