require 'dynamoid'
require 'aws-sdk-core'

class RailsEventStoreDynamoid::Event
  include Dynamoid::Document

  table name: 'event_store_events'

	field :stream, :string
	field :event_type, :string
	field :meta, :raw
	field :data, :raw

	global_secondary_index hash_key: :stream, range_key: :created_at

  before_save :sanitize_raw_fields

  def sanitize_raw_fields
    self.meta = _sanitize_hash(self.meta) if self.meta.is_a?(Hash)
    self.data = _sanitize_hash(self.data) if self.data.is_a?(Hash)
  end

  def _sanitize_hash(hash)
    hash.reject do |k, v|
      v.nil? || ((v.is_a?(Set) || v.is_a?(String)) && v.empty?)
    end
  end
end