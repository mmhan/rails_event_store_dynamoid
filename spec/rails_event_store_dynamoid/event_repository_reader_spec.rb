require 'spec_helper'
require 'ruby_event_store'

# @private
class SRecord
  def self.new(
    event_id:   SecureRandom.uuid,
    data:       SecureRandom.uuid,
    metadata:   SecureRandom.uuid,
    event_type: SecureRandom.uuid
  )
    RubyEventStore::SerializedRecord.new(
      event_id:   event_id,
      data:       data,
      metadata:   metadata,
      event_type: event_type,
    )
  end
end

describe RailsEventStoreDynamoid::EventRepositoryReader do
  describe ".read" do
    subject { described_class.new }
    let(:repository) { RailsEventStoreDynamoid::EventRepository.new }
    let(:specification) { RubyEventStore::Specification.new(repository, RubyEventStore::Mappers::NullMapper.new) }
    let(:global_stream) { RubyEventStore::Stream.new(RubyEventStore::GLOBAL_STREAM) }
    let(:global_stream_sname) { RailsEventStoreDynamoid::EventRepository::SERIALIZED_GLOBAL_STREAM_NAME }
    let(:stream) { RubyEventStore::Stream.new(SecureRandom.uuid) }
    let(:version_none)  { RubyEventStore::ExpectedVersion.none }
    let(:version_auto)  { RubyEventStore::ExpectedVersion.auto }
    let(:version_any)   { RubyEventStore::ExpectedVersion.any }
    let(:version_0)     { RubyEventStore::ExpectedVersion.new(0) }
    let(:version_1)     { RubyEventStore::ExpectedVersion.new(1) }
    let(:version_2)     { RubyEventStore::ExpectedVersion.new(2) }
    let(:version_3)     { RubyEventStore::ExpectedVersion.new(3) }

    context "non global stream" do
      it "preserves the order with which the records are inserted" do
        repository.
        append_to_stream(event0 = SRecord.new, stream, version_none).
        append_to_stream(event1 = SRecord.new, stream, version_0).
        append_to_stream(event2 = SRecord.new, stream, version_1)

        query = subject.read(specification.
         stream(stream.name).
         result)

        expect(query.map(&:event_id)).to eq([event0, event1, event2].map(&:event_id))
      end

      it "correctly selects with limit" do
        repository.
        append_to_stream(event0 = SRecord.new, stream, version_none).
        append_to_stream(event1 = SRecord.new, stream, version_0)

        result = subject.read(specification.
         stream(stream.name).
         limit(1).
         result)

        expect(result.first.event_id).to eq(event0.event_id)
      end

      it "can query with start condition" do
        repository.
        append_to_stream(event0 = SRecord.new, stream, version_none).
        append_to_stream(event1 = SRecord.new, stream, version_0).
        append_to_stream(event2 = SRecord.new, stream, version_1)

        result_from_head = subject.read(specification.
         stream(stream.name).
         from(:head).
         result)
        all_events = result_from_head.map(&:event_id)
        expect(all_events).to eq([event0, event1, event2].map(&:event_id))

        result_from_event1 = subject.read(specification.
          stream(stream.name).
          from(event1.event_id).
          result)
        expected_event2 = result_from_event1.map(&:event_id)
        expect(expected_event2).to eq([event2.event_id])
      end

      it "lets you reverse the order" do
        repository
        .append_to_stream(event0 = SRecord.new, stream, version_none)
        .append_to_stream(event1 = SRecord.new, stream, version_0)
        .append_to_stream(event2 = SRecord.new, stream, version_1)

        backward_result = subject.read(
          specification
          .stream(stream.name)
          .from(:head)
          .backward
          .result
          )

        expect(backward_result.map(&:event_id)).to eq([event2, event1, event0].map(&:event_id))
      end
    end

    context 'global stream' do
      it "can query global events" do
        repository.append_to_stream(event = SRecord.new, stream, version_none)

        spec = specification.from(:head).limit(1).result
        expect(subject.read(spec).first).to eq(event)
      end
    end
  end
end
