require File.join(File.dirname(__FILE__), "spec_helper")

describe (klass = SmartTuple) do
  r = nil
  before :each do
    r = klass.new(" AND ")
  end

  it "is initially empty" do
    r.empty?.should == true
    r.compile.should == []
    r.size.should == 0
  end

  describe "bracketing logic" do
    it "never puts brackets around a single statement" do
      [true, false, :auto].each do |mode|
        r = klass.new(" AND ", :brackets => mode)
        r << ["age < ?", 25]
        r.compile.should == ["age < ?", 25]
      end
    end

    describe "[SC1]" do
      before :each do
        r = klass.new(" AND ")
        r << ["is_male = ?", true]
        r << ["age >= ? AND age <= ?", 18, 35]
      end

      it "works if brackets = true" do
        r.brackets = true
        r.compile.should == ["(is_male = ?) AND (age >= ? AND age <= ?)", true, 18, 35]
      end

      it "works if brackets = false" do
        r.brackets = false
        r.compile.should == ["is_male = ? AND age >= ? AND age <= ?", true, 18, 35]
      end

      it "works if brackets = :auto" do
        r.brackets = :auto
        r.compile.should == ["is_male = ? AND (age >= ? AND age <= ?)", true, 18, 35]
      end
    end

    describe "[SC1.1]" do
      # NOTE: This SC has brackets DELIBERATELY undetected.
      before :each do
        r = klass.new(" AND ")
        r << ["is_male = 1"]
        r << ["age >= 18 AND age <= 35"]
      end

      it "works if brackets = true" do
        r.brackets = true
        r.compile.should == ["(is_male = 1) AND (age >= 18 AND age <= 35)"]
      end

      it "works if brackets = false" do
        r.brackets = false
        r.compile.should == ["is_male = 1 AND age >= 18 AND age <= 35"]
      end

      it "works if brackets = :auto" do
        r.brackets = :auto
        r.compile.should == ["is_male = 1 AND age >= 18 AND age <= 35"]
      end
    end

    describe "[SC2]" do
      before :each do
        r = klass.new(" AND ")
        r << ["is_male = ?", true]
        r << klass.new(" AND ") + ["age >= ?", 18] + ["age <= ?", 35]   # stmt: 1+1, args: 1+1
      end

      it "works if brackets = true" do
        r.brackets = true
        r.compile.should == ["(is_male = ?) AND (age >= ? AND age <= ?)", true, 18, 35]
      end

      it "works if brackets = false" do
        r.brackets = false
        r.compile.should == ["is_male = ? AND age >= ? AND age <= ?", true, 18, 35]
      end

      it "works if brackets = :auto" do
        r.brackets = :auto
        r.compile.should == ["is_male = ? AND (age >= ? AND age <= ?)", true, 18, 35]
      end
    end

    describe "[SC2.1]" do
      before :each do
        r = klass.new(" AND ")
        r << ["is_male = ?", true]
        r << klass.new(" AND ") + ["age >= ? AND age <= ?", 18, 35]   # stmt: 1, args: 2
      end

      it "works if brackets = true" do
        r.brackets = true
        r.compile.should == ["(is_male = ?) AND (age >= ? AND age <= ?)", true, 18, 35]
      end

      it "works if brackets = false" do
        r.brackets = false
        r.compile.should == ["is_male = ? AND age >= ? AND age <= ?", true, 18, 35]
      end

      it "works if brackets = :auto" do
        r.brackets = :auto
        r.compile.should == ["is_male = ? AND (age >= ? AND age <= ?)", true, 18, 35]
      end
    end

    describe "[SC2.2]" do
      before :each do
        r = klass.new(" AND ")
        r << ["is_male = ?", true]
        r << klass.new(" AND ") + "age >= 18" + "age <= 35" # stmt: 1+1, args: 0
      end

      it "works if brackets = true" do
        r.brackets = true
        r.compile.should == ["(is_male = ?) AND (age >= 18 AND age <= 35)", true]
      end

      it "works if brackets = false" do
        r.brackets = false
        r.compile.should == ["is_male = ? AND age >= 18 AND age <= 35", true]
      end

      it "works if brackets = :auto" do
        r.brackets = :auto
        r.compile.should == ["is_male = ? AND (age >= 18 AND age <= 35)", true]
      end
    end

    describe "[SC2.3]" do
      # NOTE: This SC has brackets DELIBERATELY undetected.
      before :each do
        r = klass.new(" AND ")
        r << ["is_male = ?", true]
        r << klass.new(" AND ") + ["age >= 18 AND age <= 35"] # stmt: 1, args: 0
      end

      it "works if brackets = true" do
        r.brackets = true
        r.compile.should == ["(is_male = ?) AND (age >= 18 AND age <= 35)", true]
      end

      it "works if brackets = false" do
        r.brackets = false
        r.compile.should == ["is_male = ? AND age >= 18 AND age <= 35", true]
      end

      it "works if brackets = :auto" do
        r.brackets = :auto
        r.compile.should == ["is_male = ? AND age >= 18 AND age <= 35", true]
      end
    end
  end # bracketing logic

  #--------------------------------------- Method tests

  # NOTE: Alphabetical order, except for #new.

  describe "#new" do
    it "requires an argument" do
      Proc.new do
        klass.new
      end.should raise_error ArgumentError

      Proc.new do
        klass.new(" AND ")
      end.should_not raise_error
    end
  end # #new

  describe "#+" do
    it "returns a copy" do
      [nil, "created_at IS NULL", ["is_pirate = ?", true]].each do |arg|
        r = klass.new(" AND ")
        #(r + arg).object_id.should_not == r.object_id
        (r + arg).should_not eql r
      end
    end
  end # #+

  # Most tests are here, since arg conversion is performed right in `<<`.
  describe "#<<" do
    it "ignores nil/empty/blank objects" do
      objs = []
      objs << nil
      objs << ""
      objs << "  " if "".respond_to? :blank?
      objs << []
      objs << {}

      objs.each do |obj|
        r = klass.new(" AND ")
        r << "field IS NULL"
        compile_before = r.compile
        r << obj
        r.compile.should == compile_before
      end
    end

    it "returns self" do
      (r << ["is_male = ?", true]).should eql r
    end

    it "supports IS NULL for Hash" do
      r << {:kk => nil}
      r.compile.should == ["kk IS NULL"]

      r << {:mkk => 10}
      r.compile.should == ["kk IS NULL AND mkk = ?", 10]
    end

    it "supports chaining" do
      r << ["age >= ?", 18] << "created_at IS NULL"
      r.compile.should == ["age >= ? AND created_at IS NULL", 18]
    end

    it "supports String" do
      r << "field1 IS NULL"
      r << "field2 IS NOT NULL"
      r.compile.should == ["field1 IS NULL AND field2 IS NOT NULL"]
    end

    it "supports Array" do
      r << ["name = ?", "John"]
      r << ["age < ?", 25]
      r.compile.should == ["name = ? AND age < ?", "John", 25]

      r = klass.new(" AND ")
      r << ["name = ? OR age = ?", "John", 25]
      r.compile.should == ["name = ? OR age = ?", "John", 25]

      r = klass.new(" AND ")
      r << ["is_male = ?", true]
      r << ["name = ? OR age = ?", "John", 25]
      r.compile.should == ["is_male = ? AND (name = ? OR age = ?)", true, "John", 25]
    end

    it "handles Array with empty/blank first statement" do
      (r << ["", 1, 2, 3]).compile.should == []
      (r << [nil, 1, 2, 3]).compile.should == []
    end

    it "supports Hash" do
      r << {:is_pirate => true}
      r << {:has_beard => true}
      r << {:drinks_rum => true}
      r.compile.should == ["is_pirate = ? AND has_beard = ? AND drinks_rum = ?", true, true, true]

      r = klass.new(" OR ")
      r << {:is_pirate => true, :smokes_pipe => false}
      [
        ["is_pirate = ? OR smokes_pipe = ?", true, false],
        ["smokes_pipe = ? OR is_pirate = ?", false, true],
      ].should include(r.compile)
    end
  end # #<<

  describe "#add_each" do
    it "generally works" do
      r.add_each([:is_pirate, :has_beard, :drinks_rum]) do |v|
        ["#{v} = ?", true]
      end.compile.should == ["is_pirate = ? AND has_beard = ? AND drinks_rum = ?", true, true, true]
    end
  end

  describe "#brackets=" do
    it "only supports true/false/:auto" do
      [true, false, :auto].each do |v|
        (r.brackets = v).should == v
      end

      Proc.new do
        r.brackets = nil
      end.should raise_error ArgumentError

      Proc.new do
        r.brackets = :something_invalid
      end.should raise_error ArgumentError
    end
  end

  describe "#clear" do
    it "generally works" do
      r.clear
      r.compile.should == []

      r << ["is_male = ?", true]
      r.clear
      r.compile.should == []
    end

    it "returns self" do
      r.clear.should eql r
    end
  end

  describe "#to_a" do
    it "generally works" do
      r << ["is_male = ?", true]
      r << ["age >= ? AND age <= ?", 18, 35]
      r.to_a.should == ["is_male = ? AND (age >= ? AND age <= ?)", true, 18, 35]
    end
  end

  describe "#size" do
    it "generally works" do
      r.size.should == 0

      r << ["is_male = ?", true]
      r.size.should == 1

      r << ["age >= ? AND age <= ?", 18, 35]
      r.size.should == 2
    end
  end
end
