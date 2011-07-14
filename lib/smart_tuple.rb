# SQL condition builder.
#
#   tup = SmartTuple.new(" AND ")
#   tup << {:brand => "Nokia"}
#   tup << ["min_price >= ?", 75]
#   tup.compile   # => ["brand = ? AND min_price >= ?", "Nokia", 75]
class SmartTuple
  # Array of SQL argument parts.
  attr_reader :args

  # Put brackets around statements. <tt>true</tt>, <tt>false</tt> or <tt>:auto</tt>. Default:
  #
  #   :auto
  attr_reader :brackets

  # String to glue statements together.
  attr_accessor :glue

  # Array of SQL statement parts.
  attr_reader :statements

  # Initializer.
  #
  #   new(" AND ")
  #   new(" OR ", :brackets => true)
  def initialize(glue, attrs = {})
    @glue = glue
    clear
    attrs.each {|k, v| send("#{k}=", v)}
  end

  # Service initializer for <tt>dup</tt>.
  def initialize_copy(src)    #:nodoc:
    @statements = src.statements.dup
    @args = src.args.dup
  end

  # Add a statement, return new object. See #<<.
  #
  #   SmartTuple.new(" AND ") + {:brand => "Nokia"} + ["max_price <= ?", 300]
  def +(arg)
    # Since #<< supports chaining, it boils down to this.
    dup << arg
  end

  # Add a statement, return self.
  #
  #   # Array.
  #   tup << ["brand = ?", "Nokia"]
  #   tup << ["brand = ? AND color = ?", "Nokia", "Black"]
  #
  #   # Hash.
  #   tup << {:brand => "Nokia"}
  #   tup << {:brand => "Nokia", :color => "Black"}
  #
  #   # Another SmartTuple.
  #   tup << other_tuple
  #
  #   # String. Generally NOT recommended.
  #   tup << "min_price >= 75"
  #
  # Adding anything empty or blank (where appropriate) has no effect on the receiver:
  #
  #   tup << nil
  #   tup << []
  #   tup << {}
  #   tup << another_empty_tuple
  #   tup << ""
  #   tup << "  "     # Will be treated as blank if ActiveSupport is on.
  def <<(arg)
    # NOTE: Autobracketing is placing `[value]` instead of `value` into `@statements`. #compile understands it.

    # Chop off everything empty first time.
    if arg.nil? or (arg.empty? rescue false) or (arg.blank? rescue false)
    elsif arg.is_a? String or (arg.acts_like? :string rescue false)
      @statements << arg.to_s
    elsif arg.is_a? Array
      # NOTE: If arg == [], the execution won't get here.
      #       So, we've got at least one element. Therefore stmt will be scalar, and args -- DEFINITELY an array.
      stmt, args = arg[0], arg[1..-1]
      if not (stmt.nil? or (stmt.empty? rescue false) or (stmt.blank? rescue false))
        # Help do autobracketing later. Here we can ONLY judge by number of passed arguments.
        @statements << (args.size > 1 ? [stmt] : stmt)
        @args += args
      end
    elsif arg.is_a? Hash
      arg.each do |k, v|
        if v.nil?
          # NOTE: AR supports it for Hashes only. ["kk = ?", nil] will not be converted.
          @statements << "#{k} IS NULL"
        else
          @statements << "#{k} = ?"
          @args << v
        end
      end
    elsif arg.is_a? self.class
      # NOTE: If arg is empty, the execution won't get here.

      # Autobrackets here are smarter, than in Array processing case.
      stmt = arg.compile[0]
      @statements << ((arg.size > 1 or arg.args.size > 1) ? [stmt] : stmt)
      @args += arg.args
    else
      raise ArgumentError, "Invalid statement #{arg.inspect}"
    end

    # Return self, it's IMPORTANT to make chaining possible.
    self
  end

  # Iterate over collection and add block's result to self once per each record.
  #
  #   add_each(brands) do |v|
  #     ["brand = ?", v]
  #   end
  #
  # Can be conditional:
  #
  #   tup.add_each(["Nokia", "Motorola"]) do |v|
  #     ["brand = ?", v] if v =~ /^Moto/
  #   end
  def add_each(collection, &block)
    raise ArgumentError, "Code block expected" if not block

    collection.each do |v|
      self << yield(v)
    end

    # This is IMPORTANT.
    self
  end

  # Set bracketing mode.
  #
  #   brackets = true         # Put brackets around each sub-statement.
  #   brackets = false        # Don't put brackets.
  #   brackets = :auto        # Automatically put brackets around compound sub-statements.
  def brackets=(value)
    raise ArgumentError, "Unknown value #{value.inspect}" if not [true, false, :auto].include? value
    @brackets = value
  end

  # Clear self.
  def clear
    @statements = []
    @args = []
    @brackets = :auto

    # `Array` does it like this. We do either.
    self
  end

  # Compile self into an array. Empty self yields empty array.
  #
  #   compile   # => []
  #   compile   # => ["brand = ? AND min_price >= ?", "Nokia", 75]
  def compile
    return [] if empty?

    # Build "bracketed" statements.
    bsta = @statements.map do |s|
      auto_brackets, scalar_s = s.is_a?(Array) ? [true, s[0]] : [false, s]

      # Logic:
      #   brackets  | auto  | result
      #   ----------|-------|-------
      #   true      | *     | true
      #   false     | *     | false
      #   :auto     | true  | true
      #   :auto     | false | false

      brackets = if @statements.size < 2
        # If there are no neighboring statements, there WILL BE NO brackets in any case.
        false
      elsif @brackets == true or @brackets == false
        @brackets
      elsif @brackets == :auto
        auto_brackets
      else
        raise "Unknown @brackets value #{@brackets.inspect}, SE"
      end

      if brackets
        ["(", scalar_s, ")"].join
      else
        scalar_s
      end
    end

    [bsta.join(glue)] + @args
  end
  alias_method :to_a, :compile

  # Return <tt>true</tt> if self is empty.
  #
  #   tup = SmartTuple.new(" AND ")
  #   tup.empty?    # => true
  def empty?
    @statements.empty?
  end

  # Get number of sub-statements.
  def size
    @statements.size
  end

  # NOTE: Decided not to make #count as an alias to #size. For other classes #count normally is a bit smarter, supports block, etc.
end
