# frozen_string_literal: true

require 'aws-sdk-ec2'
require 'aws-sdk-rds'
require 'glimmer-dsl-libui'
require 'logger'

require_relative 'rds_instance'
require_relative 'rds_snapshot'

# class DbInstances
class DbInstances
  attr_accessor :client, :databases, :database, :region, :regions, :snapshots, :snapshot, :logger

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
    client = Aws::RDS::Client.new(region: region)
    client.describe_db_instances.db_instances.each_with_index.map do |it, idx|
      databases << RdsInstance.new(
        it.db_instance_identifier,
        it.db_instance_status,
        it.multi_az,
        it.allocated_storage,
        it.max_allocated_storage,
        it.endpoint,
        it.db_subnet_group,
        it.vpc_security_groups,
        it.ca_certificate_identifier,
        it.db_parameter_groups,
        idx.even? ? 'oldlace' : 'white'
      )
    end
  end

  def get_snapshots(db)
    client = Aws::RDS::Client.new(region: region)
    client.describe_db_snapshots(db_instance_identifier: db)
          .db_snapshots
          .sort_by(&:snapshot_create_time)
          .reverse
          .each_with_index
          .map do |it, idx|
      snapshots << RdsSnapshot.new(
        it.db_snapshot_identifier,
        it.db_instance_identifier,
        it.snapshot_create_time,
        it.allocated_storage,
        it.status,
        it.availability_zone,
        it.snapshot_type,
        idx.even? ? 'oldlace' : 'white'
      )
    end
  end

  def clear_databases
    self.database = nil
    databases.clear
  end

  def clear_snapshots
    self.snapshot = nil
    snapshots.clear
  end

  def valid?(db)
    valid = false

    if snapshots.empty?
      msg_box('No snapshots available to restore from. Choose a different DB instance or create a snapshot first')
    elsif db.text.empty?
      msg_box('Please enter a new DB name to restore to')
    elsif !snapshot
      msg_box('Please choose a snapshot')
    elsif snapshot.status != 'available'
      msg_box('Please choose a snapshot with a status of "available"')
    elsif databases.collect(&:db_instance_identifier).include?(db.text)
      msg_box("A database with the name '#{db.text}' already exists. Please choose a different name")
    elsif db.text.length < 3 || db.text.length > 63
      msg_box('DB name must be between 3 and 63 characters')
    elsif db.text.match(/[^a-z0-9-]/)
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
                on_clicked do |_table, _row|
                  if valid?(new_db)
                    client = Aws::RDS::Client.new(region: region)
                    client.restore_db_instance_from_db_snapshot(
                      db_instance_identifier: new_db.text,
                      db_snapshot_identifier: snapshot.db_snapshot_identifier,
                      multi_az: false,
                      ca_certificate_identifier: database.ca_certificate_identifier,
                      db_subnet_group_name: database.db_subnet_group.db_subnet_group_name,
                      db_parameter_group_name: database.db_parameter_groups.first.db_parameter_group_name,
                      vpc_security_group_ids: database.vpc_security_groups.select do |it|
                        it.status == 'active'
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
