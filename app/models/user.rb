# frozen_string_literal: true
class User < ApplicationRecord
  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User
  include Hydra::User
  # Connects this user object to Role-management behaviors.
  include Hydra::RoleManagement::UserRoles

  def self.from_omniauth(access_token)
    User.where(provider: access_token.provider, uid: access_token.uid).first_or_create do |user|
      user.uid = access_token.uid
      user.provider = access_token.provider
      user.email = "#{access_token.uid}@princeton.edu"
    end
  end
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :omniauthable, omniauth_providers: [:cas]

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account.
  def to_s
    uid
  end

  def admin?
    groups.include?('admin')
  end

  def ephemera_editor?
    roles.where(name: 'ephemera_editor').exists?
  end

  def image_editor?
    roles.where(name: 'image_editor').exists?
  end

  def completer?
    roles.where(name: 'completer').exists?
  end

  def editor?
    roles.where(name: 'editor').exists?
  end

  def fulfiller?
    roles.where(name: 'fulfiller').exists?
  end

  def curator?
    roles.where(name: 'curator').exists?
  end

  def campus_patron?
    persisted? && provider == "cas"
  end

  def anonymous?
    !persisted?
  end
end
