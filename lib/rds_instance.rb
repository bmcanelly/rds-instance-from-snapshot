# frozen_string_literal: true

RdsInstance = Struct.new(:db_instance_identifier, :db_instance_status, :multi_az, :allocated_storage,
                         :max_allocated_storage, :endpoint, :db_subnet_group, :vpc_security_groups, :ca_certificate_identifier, :db_parameter_groups, :background_color)
