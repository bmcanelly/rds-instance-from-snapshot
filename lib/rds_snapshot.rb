# frozen_string_literal: true

RdsSnapshot = Struct.new(:db_snapshot_identifier, :db_instance_identifier, :snapshot_create_time, :allocated_storage,
                         :status, :availability_zone, :snapshot_type, :background_color)
