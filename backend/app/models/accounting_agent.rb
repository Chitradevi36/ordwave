# frozen_string_literal: true

class AccountingAgent < ApplicationRecord
  include AccountingTenantValidatable

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  belongs_to :organization
  belongs_to :accounting_integration

  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------
  enum status: {
    online:  "online",
    offline: "offline",
    error:   "error"
  }, _prefix: :status

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :organization, presence: true
  validates :accounting_integration, presence: true
  validates :agent_id, presence: true, uniqueness: true
  validates :api_key_digest, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------
  before_validation :generate_agent_id, on: :create
  before_validation :set_registered_at, on: :create

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  scope :online, -> { where("last_heartbeat_at > ?", 2.minutes.ago).where(status: "online") }
  scope :offline, -> { where("last_heartbeat_at IS NULL OR last_heartbeat_at <= ?", 2.minutes.ago) }
  scope :recently_active, -> { where("last_heartbeat_at > ?", 24.hours.ago).order(last_heartbeat_at: :desc) }

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------

  # Check if agent is currently online based on last heartbeat
  def online?
    last_heartbeat_at.present? && last_heartbeat_at > 2.minutes.ago && status_online?
  end

  # Generate and store a new API key
  # @return [String] the plaintext API key (only returned once)
  def generate_api_key
    key = SecureRandom.hex(32)
    self.api_key_digest = BCrypt::Password.create(key)
    key
  end

  # Verify an API key against the stored digest
  # @param key [String] the plaintext API key to verify
  # @return [Boolean] true if the key matches
  def verify_api_key(key)
    return false if api_key_digest.blank?
    BCrypt::Password.new(api_key_digest) == key
  rescue BCrypt::Errors::InvalidHash
    false
  end

  # Record a heartbeat from the agent
  def record_heartbeat!(agent_version: nil, os_info: nil, tally_version: nil)
    update!(
      last_heartbeat_at: Time.current,
      status: "online",
      agent_version: agent_version || self.agent_version,
      os_info: os_info || self.os_info,
      tally_version: tally_version || self.tally_version
    )
  end

  # Mark agent as offline
  def mark_offline!
    update!(status: "offline")
  end

  # Mark agent as error state with optional message
  def mark_error!(message = nil)
    update!(status: "error")
  end

  private

  def generate_agent_id
    self.agent_id ||= "agent_#{SecureRandom.uuid}"
  end

  def set_registered_at
    self.registered_at ||= Time.current
  end
end
