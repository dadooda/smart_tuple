class SmartTuple
  attr_reader :args
  attr_reader :brackets
  attr_accessor :glue
  attr_reader :statements

  #   new(" AND ")
  #   new(" OR ")
  #   new(", ")       # E.g. for a SET or UPDATE statement.
  def initialize(glue, attrs = {})
    @glue = glue
    clear
    attrs.each {|k, v| send("#{k}=", v)}
  end

  # We need it to control #dup behaviour.
  def initialize_copy(src)
    @statements = src.statements.dup
    @args = src.args.dup
  end

  # NOTE: Alphabetical order below.

  # Add a sub-statement, return new object. See <tt>#&lt;&lt;</tt>.
  #   SmartTuple.new(" AND ") + {:brand => "Nokia"} + ["max_price <= ?", 300]
  def +(sub)
    # Since #<< supports chaining, it boils down to this.
    dup << sub
  end

  # Append a sub-statement.
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
  #   tup << "brand IS NULL"
  #
  # Appending empty or blank (where appropriate) statements has no effect on the receiver:
  #   tup << nil
  #   tup << []
  #   tup << {}
  #   tup << another_empty_tuple
  #   tup << ""
  #   tup << "  "     # Will be treated as blank if ActiveSupport is on.
  def <<(sub)
    ##p "self.class", self.class

    # NOTE: Autobracketing help is placing [value] instead of (value) into @statements. #compile will take it into account.

    # Chop off everything empty first time.
    if sub.nil? or (sub.empty? rescue false) or (sub.blank? rescue false)
      ##puts "-- empty"
    elsif sub.is_a? String or (sub.acts_like? :string rescue false)
      ##puts "-- is a string"
      @statements << sub.to_s
    elsif sub.is_a? Array
      # NOTE: If sub == [], the execution won't get here.
      #       So, we've got at least one element. Therefore stmt will be scalar, and args -- DEFINITELY an array.
      stmt, args = sub[0], sub[1..-1]
      ##p "stmt", stmt
      ##p "args", args
      if not (stmt.nil? or (stmt.empty? rescue false) or (stmt.blank? rescue false))
        ##puts "-- stmt nempty"
        # Help do autobracketing later. Here we can ONLY judge by number of passed arguments.
        @statements << (args.size > 1 ? [stmt] : stmt)
        @args += args
      end
    elsif sub.is_a? Hash
      sub.each do |k, v|
        if v.nil?
          # NOTE: AR supports it for hashes only. ["kk = ?", nil] will not be converted.
          @statements << "#{k} IS NULL"
        else
          @statements << "#{k} = ?"
          @args << v
        end
      end
    elsif sub.is_a? self.class
      # NOTE: If sub is empty, the execution won't get here.

      # Autobrackets here are smarter, than in Array processing case.
      stmt = sub.compile[0]
      @statements << ((sub.size > 1 or sub.args.size > 1) ? [stmt] : stmt)
      @args += sub.args
    else
      raise ArgumentError, "Invalid sub-statement #{sub.inspect}"
    end

    # Return self, it's IMPORTANT to make chaining possible.
    self
  end

  # Iterate over collection and add block's result per each record.
  #   add_each(brands) do |v|
  #     ["brand = ?", v]
  #   end
  #
  # Can be conditional:
  #   tup.add_each(["Nokia", "Motorola"]) do |v|
  #     ["brand = ?", v] if v =~ /^Moto/
  #   end
  def add_each(collection, &block)
    raise ArgumentError, "Code block expected" if not block
    ##p "collection", collection
    collection.each do |v|
      self << yield(v)
    end

    # This is IMPORTANT.
    self
  end

  # Set bracketing mode.
  #   brackets = true         # Put brackets around each sub-statement.
  #   brackets = false        # Don't put brackets.
  #   brackets = :auto        # Automatically put brackets around compound sub-statements.
  def brackets=(value)
    raise ArgumentError, "Unknown value #{value.inspect}" if not [true, false, :auto].include? value
    @brackets = value
  end

  # Set self into default state.
  def clear
    @statements = []
    @args = []
    @brackets = :auto

    # Array does it like this. We do either.
    self
  end

  # Compile self into an array.
  def compile
    return [] if empty?

    ##p "@statements", @statements
    ##p "@args", @args

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

  def empty?
    @statements.empty?
  end

  # Get number of sub-statements.
  def size
    @statements.size
  end

  # NOTE: Decided not to make #count as an alias to #size. For other classes #count normally is a bit smarter, supports block, etc.
end
