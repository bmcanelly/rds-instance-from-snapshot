# frozen_string_literal: true

require 'aws-sdk-ec2'
require 'aws-sdk-rds'
require 'glimmer-dsl-libui'
require 'logger'

require_relative 'rds_instance'
require_relative 'rds_snapshot'

class DbInstances
  attr_accessor :databases, :database, :region, :snapshots, :snapshot, :logger
  attr_reader :regions

  include Glimmer

  def initialize
    self.databases = []
    self.logger = Logger.new('log/app.log')
    self.region = 'us-east-1'
    self.snapshots = []
  end

  def get_regions
    ec2 = Aws::EC2::Client.new(region: 'us-east-1')
    ec2.describe_regions.regions.map(&:region_name).sort!
  end

  def get_rds_databases
    rds_client.describe_db_instances.db_instances.each_with_index do |instance, idx|
      databases << RdsInstance.new(
        instance.db_instance_identifier,
        instance.db_instance_status,
        instance.multi_az,
        instance.allocated_storage,
        instance.max_allocated_storage,
        instance.endpoint,
        instance.db_subnet_group,
        instance.vpc_security_groups,
        instance.ca_certificate_identifier,
        instance.db_parameter_groups,
        idx.even? ? 'oldlace' : 'white'
      )
    end
  end

  def get_snapshots(db)
    rds_client.describe_db_snapshots(db_instance_identifier: db)
              .db_snapshots
              .sort_by(&:snapshot_create_time)
              .reverse!
              .each_with_index do |snap, idx|
      snapshots << RdsSnapshot.new(
        snap.db_snapshot_identifier,
        snap.db_instance_identifier,
        snap.snapshot_create_time,
        snap.allocated_storage,
        snap.status,
        snap.availability_zone,
        snap.snapshot_type,
        idx.even? ? 'oldlace' : 'white'
      )
    end
  end

  private

  def rds_client
    @rds_clients ||= {}
    @rds_clients[region] ||= Aws::RDS::Client.new(region: region)
  end

  public

  def clear_databases
    self.database = nil
    databases.clear
  end

  def clear_snapshots
    self.snapshot = nil
    snapshots.clear
  end

  def valid?(db)
    name = db.text
    valid = false

    if snapshots.empty?
      msg_box('No snapshots available to restore from. Choose a different DB instance or create a snapshot first')
    elsif name.empty?
      msg_box('Please enter a new DB name to restore to')
    elsif !snapshot
      msg_box('Please choose a snapshot')
    elsif snapshot.status != 'available'
      msg_box('Please choose a snapshot with a status of "available"')
    elsif databases.any? { |d| d.db_instance_identifier == name }
      msg_box("A database with the name '#{name}' already exists. Please choose a different name")
    elsif name.length < 3 || name.length > 63
      msg_box('DB name must be between 3 and 63 characters')
    elsif name.match(/[^a-z0-9-]/)
      msg_box('DB name must contain only lowercase letters, numbers, and hyphens')
    else
      valid = true
    end

    valid
  end

  def display
    @regions = get_regions
    get_rds_databases

    window('Restore Database Instance From Snapshot', 800, 800) do
      margined true

      vertical_box do
        form do
          stretchy false

          combobox do
            label 'Region:'
            items @regions
            selected @regions.index('us-east-1')

            on_selected do |c|
              clear_databases
              clear_snapshots
              logger.info("Switching region from #{region} to #{regions[c.selected]}")
              self.region = regions[c.selected]
              get_rds_databases
            end
          end

          button('Refresh') do
            on_clicked do
              clear_databases
              clear_snapshots
              get_rds_databases
            end
          end
        end

        horizontal_separator { stretchy false }

        vertical_box do
          form do
            stretchy false

            label "\nSelect an Instance"
          end

          table do
            text_column('Name')
            text_column('Status')
            text_column('Storage')
            text_column('Max Storage')
            background_color_column

            editable false
            cell_rows <=> [
              self,
              :databases,
              column_attributes: {
                'Name'        => :db_instance_identifier,
                'Status'      => :db_instance_status,
                'Storage'     => :allocated_storage,
                'Max Storage' => :max_allocated_storage
              }
            ]

            on_row_clicked do |_table, row|
              clear_snapshots
              self.database = databases[row]
              get_snapshots(database.db_instance_identifier)
              logger.info("Selected database: #{database.db_instance_identifier}")
            end
          end

          horizontal_separator { stretchy false }

          vertical_box do
            form do
              stretchy false
              label "\nSelect a snapshot"
            end

            table do
              text_column('Name')
              text_column('Created')
              text_column('Status')
              background_color_column

              editable false
              cell_rows <=> [
                self,
                :snapshots,
                column_attributes: {
                  'Name'    => :db_snapshot_identifier,
                  'Created' => :snapshot_create_time
                }
              ]
              on_row_clicked do |_table, row|
                self.snapshot = snapshots[row]
                logger.info("Selected snapshot: #{snapshot.db_snapshot_identifier}")
              end
            end

            form do
              stretchy false

              label 'Enter the new db name to restore to:'
              new_db = entry { label 'New DB name' }

              button('Restore') do
                on_clicked do
                  if valid?(new_db)
                    rds_client.restore_db_instance_from_db_snapshot(
                      db_instance_identifier:    new_db.text,
                      db_snapshot_identifier:    snapshot.db_snapshot_identifier,
                      multi_az:                  false,
                      ca_certificate_identifier: database.ca_certificate_identifier,
                      db_subnet_group_name:      database.db_subnet_group.db_subnet_group_name,
                      db_parameter_group_name:   database.db_parameter_groups.first.db_parameter_group_name,
                      vpc_security_group_ids:    database.vpc_security_groups.select do |sg|
                        sg.status == 'active'
                      end.map(&:vpc_security_group_id)
                    )
                    msg = "Request to restore snapshot '#{snapshot.db_snapshot_identifier}'" \
                          "as '#{new_db.text}' in region '#{region}' has been sent."
                    msg_box(msg)
                    logger.info(msg)
                    new_db.text = ''
                  end
                end
              end
            end
          end
        end
      end

      on_closing do
        logger.info('User requested exit')
        logger.close
      end
    end.show
  end
end
