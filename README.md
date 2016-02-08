# TableRotate

## Quick Start

Setup your model like so:

```ruby
class MyModel < ActiveRecord::Base
  include TableRotate
  def self.min_time_between_archives; 1.day; end
  def self.max_archive_count; 3; end
end
```

Then setup a cron job that does this:

    # TODO: This isn't implemented yet!
    rake table_rotate:archive class=MyModel

Or if you want to use something in pure ruby, to do it, run this:

```ruby
MyModel.archive!
```

Query like this:

```ruby
# Find an instance by its unique ID
model = MyModel.and_archives.reduce(nil) do |acc, klass|
  acc ||= klass.find_by_id(5)
end

# Find many instances using AREL
results = TestModel.and_archives.map do |klass|
  klass.where("value like '%abc%'")
end.flatten
```

## The Concept

Sometimes you have a lot of transient data and it would be nice to keep it in
mysql. The trouble is that mysql isn't great about freeing space. Whether or
not you delete rows from the table, you'll keep taking up disk until you
`alter table` or `optimize table`, both of which are potentially heavy
operations.

`TableRotate` lets you trade average find speed and atomicity for the ability
to clean up with no efficiency cost. Depending on the type of data you have,
this might be a good fit.

It accomplishes this by building a copy of your target table without any data,
then performing an atomic rename operation. Inserts will keep coming in without
a hitch, and you can use idiomatic ruby to query all the tables.

## Requirements, Suggestions, and Caveats

- Should use mysql, innodb configured with file per table so that disk is
  reclaimed
- Requires ActiveRecord
- Beware: archived models will not appear as associations for other
  ActiveRecord objects unless you explicitly set that up.
- `MyModel.archive!` will raise a `NotEnoughTimeBetweenArchivesError` if you
  call it before enough time has elapsed. This is to protect you.
- To avoid potential race conditions, your configured `max_archive_count`
  should be greater than the number of archives you operate on. For example, if
  I do `MyModel.and_archives(2)`, then `max_archive_count` should be at least 3.
- This works best when the model is append-only; otherwise you run into some
  race conditions for instances loaded before a rotation and saved afterward.
- Be careful! We're dropping and renaming tables here!

### Is LHM a better fit for you?

If it's important for you to have functional first-class rails associations,
then consider using [LHM](https://github.com/soundcloud/lhm) with a no-op
migration instead:

```ruby
Lhm.change_table(:the_table, atomic_switch: true) do
  puts "rebuilding..."
end
Lhm.cleanup(true)
```

LHM will perform similar steps, but will migrate data between tables. To do
this, both tables and data sets must exist at the same time, and be updated in
lock step via triggers. This is a great solution and highly recommended. Just
watch out for deadlocks and the extra space it uses while running!

## Running specs

    bundle install
    DATABASE_ENV=test rake db:create
    rspec
