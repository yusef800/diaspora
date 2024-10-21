# frozen_string_literal: true

module Admin
  # controller for managing user accounts and roles within the admin interface
  class UsersController < AdminController
    # ensures the user exists before making any actions
    before_action :validate_user, only: %i(make_admin remove_admin make_moderator remove_moderator make_spotlight remove_spotlight)

    # schedules a closure of a user's account
    def close_account
      u = User.find(params[:id])
      u.close_account!
      redirect_to user_search_path, notice: t("admins.user_search.account_closing_scheduled", name: u.username)
    end

    # prevent access to an account
    def lock_account
      u = User.find(params[:id])
      u.lock_access!
      redirect_to user_search_path, notice: t("admins.user_search.account_locking_scheduled", name: u.username)
    end

    # allow access to a previously locked account
    def unlock_account
      u = User.find(params[:id])
      u.unlock_access!
      redirect_to user_search_path, notice: t("admins.user_search.account_unlocking_scheduled", name: u.username)
    end

    # grants the role of admin to a user
    def make_admin
      unless Role.is_admin? @user.person
        Role.add_admin @user.person
        notice = "admins.user_search.add_admin"
      else
        notice = "admins.user_search.role_implemented"
      end
      redirect_to user_search_path, notice: t(notice, name: @user.username)
    end

    # removes the role of admin from a user
    def remove_admin
      if Role.is_admin? @user.person
        Role.remove_admin @user.person
        notice = "admins.user_search.delete_admin"
      else
        notice = "admins.user_search.role_removal_implemented"
      end
      redirect_to user_search_path, notice: t(notice, name: @user.username)
    end

    # grants the role of moderator to a user
    def make_moderator
      unless Role.moderator_only? @user.person
        Role.add_moderator @user.person
        notice = "admins.user_search.add_moderator"
      else
        notice = "admins.user_search.role_implemented"
      end
      redirect_to user_search_path, notice: t(notice, name: @user.username)
    end

    # removes the role of moderator from a user
    def remove_moderator
      if Role.moderator_only? @user.person
        Role.remove_moderator @user.person
        notice = "admins.user_search.delete_moderator"
      else
        notice = "admins.user_search.role_removal_implemented"
      end
      redirect_to user_search_path, notice: t(notice, name: @user.username)
    end

    # grants user the spotlight role
    def make_spotlight
      unless Role.spotlight? @user.person
        Role.add_spotlight @user.person
        notice = "admins.user_search.add_spotlight"
      else
        notice = "admins.user_search.role_implemented"
      end
      redirect_to user_search_path, notice: t(notice, name: @user.username)
    end

    # removes spotlight role from user
    def remove_spotlight
      if Role.spotlight? @user.person
        Role.remove_spotlight @user.person
        notice = "admins.user_search.delete_spotlight"
      else
        notice = "admins.user_search.role_removal_implemented"
      end
      redirect_to user_search_path, notice: t(notice, name: @user.username)
    end

    private

    # validates that a user exists before performing actions
    # redirects to an error if the user is not found
    def validate_user
      @user = User.where(id: params[:id]).first
      redirect_to user_search_path, notice: t("admins.user_search.does_not_exist") unless @user
    end
  end
end
