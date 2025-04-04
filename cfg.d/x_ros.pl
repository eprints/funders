# EPrints Services/sf2
# 
# ROS fields/Reports
#

# ROS Status: has this publication been submitted to ROS already?
$c->add_dataset_field( 'eprint',
        {
                name => "ros_submitted",
                type => "boolean",
                default_value => 'FALSE',
        },
        reuse => 1
);

# ROS Action: should this publication be sent to ROS at all?
$c->add_dataset_field( 'eprint',
        {
                name => "ros_action",
                type => "set",
                options => [qw/ auto none /],
                default_value => 'auto'
        },
        reuse => 1,
);

# ROS Submission date: if in ROS, when was this publication added to ROS?
$c->add_dataset_field( 'eprint',
        {
                name => "ros_sub_date",
                type => "date",
                sql_index => 0
        },
        reuse => 1
);

# ROS UID - Internal ID
$c->add_dataset_field( 'eprint',
        {
                name => "ros_id",
                type => "longtext",
                sql_index => 0,
                text_index => 0,
        },
        reuse => 1
);

# ROS Log - for automatic import - keep a log of this was achieved - might be empty
$c->add_dataset_field( 'eprint',
        {
                name => "ros_import_log",
                type => "longtext",
                sql_index => 0,
                text_index => 0
        },
	reuse => 1
);
