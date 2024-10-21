# frozen_string_literal: true

class AdminsController < Admin::AdminController
  include ApplicationHelper

  # renders the admin dashboard and refreshes the pod version on the server
  def dashboard
    gon.push(pod_version: pod_version)
  end

  # allows searching for users based on provided parameters
  def user_search
    if params[:admins_controller_user_search]
      search_params = params.require(:admins_controller_user_search)
                            .permit(:username, :email, :guid, :under13)
      @search = UserSearch.new(search_params)
      @users = @search.perform
    end

    # sets default values if no parameters were provided
    @search ||= UserSearch.new
    @users ||= []
  end

  # sends an invite to the provided email if the user doesn't exist
  def admin_inviter
    inviter = InvitationCode.default_inviter_or(current_user)
    email = params[:identifier]
    user = User.find_by_email(email) # checks if user exists

    unless user
      EmailInviter.new(email, inviter).send! # sends invite via email
      flash[:notice] = "invitation sent to #{email}"
    else
      flash[:notice]= "error sending invite to #{email}" # error if the user exists
    end
    redirect_to user_search_path, :notice => flash[:notice]
  end

  # adds more invites the the specified invitation code
  def add_invites
    InvitationCode.find_by_token(params[:invite_code_id]).add_invites!
    redirect_to user_search_path
  end

  # generates weekly user statistics
  def weekly_user_stats
    # Initializes a hash with default values as empty arrays
    @created_users_by_week = Hash.new{ |h,k| h[k] = [] }
    
    # retrieves users with non-null usernames and creation dates
    @created_users = User.where("username IS NOT NULL and created_at IS NOT NULL")
    
    # groups users by the week they were created
    @created_users.find_each do |u|
      week = u.created_at.beginning_of_week.strftime("%Y-%m-%d")
      @created_users_by_week[week] << {username: u.username, closed_account: u.person.closed_account}
    end

    @selected_week = params[:week] || @created_users_by_week.keys.last
    @counter = @created_users_by_week[@selected_week].count
  end

  # displays various statistics about user activity
  def stats
    # retrieves 50 most popular tags based on number of taggings
    @popular_tags = ActsAsTaggableOn::Tagging.joins(:tag)
                                             .limit(50)
                                             .order(Arel.sql("count(taggings.id) DESC"))
                                             .group(:tag)
                                             .count

    case params[:range]
    when "week"
      range = 1.week
      @segment = t('admins.stats.week')
    when "2weeks"
      range = 2.weeks
      @segment = t('admins.stats.2weeks')
    when "month"
      range = 1.month
      @segment = t('admins.stats.month')
    else
      range = 1.day
      @segment = t('admins.stats.daily')
    end

    # collects statistics for various models over the selected range
    [Post, Comment, AspectMembership, User].each do |model|
      create_hash(model, :range => range)
    end

    # retrieves the # of posts created per day over the last 21 days
    @posts_per_day = Post.where("created_at >= ?", Time.zone.today - 21.days)
                         .group(Arel.sql("DATE(created_at)"))
                         .order(Arel.sql("DATE(created_at) ASC"))
                         .count
    @most_posts_within = @posts_per_day.values.max.to_f

    @user_count = User.count

    #@posts[:new_public] = Post.where(:type => ['StatusMessage','ActivityStreams::Photo'],
    #                                 :public => true).order('created_at DESC').limit(15).all

  end

  private

  # calculates the percentage change between two values
  def percent_change(today, yesterday)
    sprintf( "%0.02f", ((today-yesterday) / yesterday.to_f)*100).to_f
  end

  # creates a hash with counts for the given model, showing daily changes
  def create_hash(model, opts={})
    opts[:range] ||= 1.day
    plural = model.to_s.underscore.pluralize
    eval(<<DATA
      @#{plural} = {
        :day_before => #{model}.where(:created_at => ((Time.now.midnight - #{opts[:range]*2})..Time.now.midnight - #{opts[:range]})).count,
        :yesterday => #{model}.where(:created_at => ((Time.now.midnight - #{opts[:range]})..Time.now.midnight)).count
      }
      @#{plural}[:change] = percent_change(@#{plural}[:yesterday], @#{plural}[:day_before])
DATA
    )
  end

  # Handles user searches with validations
  class UserSearch
    include ActiveModel::Model
    include ActiveModel::Conversion
    include ActiveModel::Validations

    attr_accessor :username, :email, :guid, :under13

    # validates that at least one search field is present
    validate :any_searchfield_present?

    def initialize(attributes={})
      assign_attributes(attributes)
      yield(self) if block_given?
    end

    def assign_attributes(values)
      values.each do |k, v|
        public_send("#{k}=", v)
      end
    end

    # ensures at least one search field is filled
    def any_searchfield_present?
      if %w(username email guid under13).all? { |attr| public_send(attr).blank? }
        errors.add :base, "no fields for search set"
      end
    end

    # performs the search based on the provided parameters
    def perform
      return User.none unless valid?

      users = User.arel_table
      people = Person.arel_table
      profiles = Profile.arel_table
      res = User.joins(person: :profile)

      # filters users based on the search parameters
      res = res.where(users[:username].matches("%#{username}%")) unless username.blank?
      res = res.where(users[:email].matches("%#{email}%")) unless email.blank?
      res = res.where(people[:guid].matches("%#{guid}%")) unless guid.blank?
      res = res.where(profiles[:birthday].gt(Date.today-13.years)) if under13 == '1'
      res
    end
  end
end
