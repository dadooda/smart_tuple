
SmartTuple: A Simple Yet Smart SQL Conditions Builder
=====================================================


Introduction
------------

Sometimes we need to build SQL `WHERE` statements which are compound or conditional by nature. **SmartTuple** simplifies this task by letting us build statements of virtually unlimited complexity out of smaller ones.

SmartTuple is suitable for use with Ruby on Rails (ActiveRecord) and other Ruby frameworks and ORMs.


Setup (Rails 3)
---------------

In your app's `Gemfile`, add:

    gem "smart_tuple"

To install the gem with RDoc/ri documentation, do a:

    $ gem install smart_tuple

Otherwise, do a `bundle install`.


Setup (Rails 2)
---------------

In your app's `config/environment.rb` do a:

    config.gem "smart_tuple"

To install the gem, do a:

    $ gem sources --add http://rubygems.org
    $ gem install smart_tuple

, or use `rake gems:install`.


Kickstart Demo
--------------

    tup = SmartTuple.new(" AND ")
    tup << {:brand => params[:brand]} if params[:brand].present?
    tup << ["min_price >= ?", params[:min_price]] if params[:min_price].present?
    tup << ["max_price <= ?", params[:max_price]] if params[:max_price].present?

    @phones = Phone.find(:all, :conditions => tup.compile)

There's a number of ways you can use SmartTuple. Some of them is covered in the tutorial below.


Tutorial
--------

Suppose we've got a mobile phone catalog with a search form. We are starting with a price filter of two values: `min_price` and `max_price`, both optional.

Filter logic:

* If the user hasn't input anything, the filter has no conditions (allows any record).
* If the user has input `min_price`, it's used in filter condition.
* If the user has input `max_price`, it's used in filter condition.
* If the user has input `min_price` and `max_price`, they both are used in filter condition.

Suppose the HTML form passed to a controller results in a `params` hash:

    params[:min_price] = 100    # Can be blank.
    params[:max_price] = 300    # Can be blank.

Now let's write condition-building code:

    # Start by creating a tuple whose statements are glued with " AND ".
    tup = SmartTuple.new(" AND ")

    # If min_price is not blank, append its statement.
    if params[:min_price].present?
      tup << ["min_price >= ?", params[:min_price]]
    end

    # Same for max_price.
    if params[:max_price].present?
      tup << ["max_price <= ?", params[:max_price]]
    end

    # Finally, fire up the query.
    @phones = Phone.find(:all, {:conditions => tup.compile})

That's basically it. Now let's see how different `params` values affect the resulting `:conditions` value. Labelled **p** and **c** in this and following listings:

    p: {}
    c: []

    p: {:max_price=>300}
    c: ["max_price <= ?", 300]

    p: {:min_price=>100, :max_price=>300}
    c: ["min_price >= ? AND max_price <= ?", 100, 300]

### Plus Another Condition ###

Let's make things a bit more user-friendly. Let user filter phones by brand. We do it by adding another field, let's call it `brand`, bearing a straight string value (that's just a simple tutorial, remember?).

Our `params` now becomes something like:

    params[:brand] = "Nokia"    # Can be blank.
    params[:min_price] = 100    # Can be blank.
    params[:max_price] = 300    # Can be blank.

Let's build a tuple:

    tup = SmartTuple.new(" AND ") +
      ({:brand => params[:brand]} if params[:brand].present?) +
      (["min_price >= ?", params[:min_price]] if params[:min_price].present?) +
      (["max_price <= ?", params[:max_price]] if params[:max_price].present?)

The above code shows that we can construct ready-made tuples with a single expression, using `+` operator. Also, if a condition is an equality test, we can use Hash notation: `{:brand => params[:brand]}`.

A quick look at `params` and `:conditions`, again:

    p: {:brand=>"Nokia"}
    c: ["brand = ?", "Nokia"]

    p: {:brand=>"Nokia", :max_price=>300}
    c: ["brand = ? AND max_price <= ?", "Nokia", 300]

    p: {:brand=>"Nokia", :min_price=>100, :max_price=>300}
    c: ["brand = ? AND min_price >= ? AND max_price <= ?", "Nokia", 100, 300]

### We Want More! ###

Since we now see how easy it's to build compound conditions, we decide to further extend our search form. Now we want to:

* Let user specify more than 1 brand.
* Let user specify a selection of colors.

From `params` perspective that's something like:

    params[:brands] = ["Nokia", "Motorola"]         # Can be blank.
    params[:min_price] = 100                        # Can be blank.
    params[:max_price] = 300                        # Can be blank.
    params[:colors] = ["Black", "Silver", "Pink"]   # Can be blank.

Quite obvious is that supplied values for brands and colors should be OR'ed. We're now facing the task of creating a "sub-tuple", e.g. to match brand, and then merging this sub-tuple into main tuple. Doing it straight is something like:

    tup = SmartTuple.new(" AND ")

    if params[:brands].present?
      subtup = SmartTuple.new(" OR ")
      params[:brands].each {|brand| subtup << ["brand = ?", brand]}
      tup << subtup
    end

Or, in a smarter way by utilizing `#add_each` method:

    tup = SmartTuple.new(" AND ")
    tup << SmartTuple.new(" OR ").add_each(params[:brands]) {|v| ["brand = ?", v]} if params[:brands].present?

The final query:

    Phone.find(:all, {:conditions => [SmartTuple.new(" AND "),
      (SmartTuple.new(" OR ").add_each(params[:brands]) {|v| ["brand = ?", v]} if params[:brands].present?),
      (["min_price >= ?", params[:min_price]] if params[:min_price].present?),
      (["max_price <= ?", params[:max_price]] if params[:max_price].present?),
      (SmartTuple.new(" OR ").add_each(params[:colors]) {|v| ["color = ?", v]} if params[:colors].present?),
    ].sum.compile})

> NOTE: In the above sample I've used `Array#sum` (available in ActiveSupport) instead of `+` to add statements to the tuple. I prefer to write it like this since it allows to comment and swap lines without breaking the syntax.

> NOTE: Recommended Rails 3 usage is:
>
>     Phone.where(...)      # Pass a compiled SmartTuple object in place of `...`.

Checking out `params` and `:conditions`:

    p: {:brands=>["Nokia"], :max_price=>300}
    c: ["brand = ? AND max_price <= ?", "Nokia", 300]

    p: {:brands=>["Nokia", "Motorola"], :max_price=>300}
    c: ["(brand = ? OR brand = ?) AND max_price <= ?", "Nokia", "Motorola", 300]
         ^--                    ^-- note the auto brackets

    p: {:brands=>["Nokia", "Motorola"], :max_price=>300, :colors=>["Black"]}
    c: ["(brand = ? OR brand = ?) AND max_price <= ? AND color = ?", "Nokia", "Motorola", 300, "Black"]

    p: {:brands=>["Nokia", "Motorola"], :colors=>["Black", "Silver", "Pink"]}
    c: ["(brand = ? OR brand = ?) AND (color = ? OR color = ? OR color = ?)", "Nokia", "Motorola", "Black", "Silver", "Pink"]

That's the end of our tutorial. Hope now you've got an idea of what SmartTuple is.


API Summary
-----------

Here's a brief cheatsheet, which outlines the main SmartTuple features.

### Appending Statements ###

    # Array.
    tup << ["brand = ?", "Nokia"]
    tup << ["brand = ? AND color = ?", "Nokia", "Black"]

    # Hash.
    tup << {:brand => "Nokia"}
    tup << {:brand => "Nokia", :color => "Black"}

    # Another SmartTuple.
    tup << other_tuple

    # String. Generally NOT recommended.
    tup << "min_price >= 75"

Appending empty or blank (where appropriate) statements has no effect on the receiver:

    tup << nil
    tup << []
    tup << {}
    tup << an_empty_tuple
    tup << ""
    tup << "  "     # Will be treated as blank if ActiveSupport is on.

Another way to append something is to use `+`.

    tup = SmartTuple.new(" AND ") + {:brand => "Nokia"} + ["max_price <= ?", 300]

Appending one statement per each collection item is easy through `#add_each`:

    tup.add_each(["Nokia", "Motorola"]) {|v| ["brand = ?", v]}

The latter can be made conditional. Remember, appending `nil` has no effect on the receiving tuple, which gives us freedom to use conditions whenever we want to:

    tup.add_each(["Nokia", "Motorola"]) do |v|
      ["brand = ?", v] if v =~ /^Moto/
    end


### Bracketing the Statements: Always, Never and Auto ###

_This chapter still has to be written._

    tup = SmartTuple.new(" AND ")
    tup.brackets
    => :auto

    tup.brackets = true
    tup.brackets = false
    tup.brackets = :auto


### Clearing ###

To put tuple into its initial state, do a:

    tup.clear


### Compiling ###

Compiling is converting the tuple into something suitable for use as `:conditions` of an ActiveRecord call.

It's as straight as:

    tup.compile
    tup.to_a        # An alias, does the same.

    # Go fetch!
    Phone.find(:all, :conditions => tup.compile)    # Rails 2
    Phone.where(tup.compile)                        # Rails 3


### Contents and Size ###

You can examine tuple's state with methods often found in other Ruby classes: `#empty?`, `#size`, and attribute accessors `#statements` and `#args`.

    tup = SmartTuple.new(" AND ")
    tup.empty?
    => true
    tup.size
    => 0

    tup << ["brand = ?", "Nokia"]
    tup.empty?
    => false
    tup.size
    => 1

    tup << ["max_price >= ?", 300]
    tup.size
    => 2

    tup.statements
    => ["brand = ?", "max_price >= ?"]
    tup.args
    => ["Nokia", 300]


Feedback
--------

Send bug reports, suggestions and criticisms through [project's page on GitHub](http://github.com/dadooda/smart_tuple).

Licensed under the MIT License.
