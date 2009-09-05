require File.join(File.dirname(__FILE__), "/../../spec_helper.rb")

describe Mongoloid::Association do

  describe "#class_name" do

    it "returns the klass supplied in the constructor" do
      association = Mongoloid::Association.new(:has_many, "Person", Person.new)
      association.class_name.should == "Person"
    end

  end

  describe "#instance" do

    it "returns the instance supplied in the constructor" do
      instance = Person.new
      association = Mongoloid::Association.new(:has_many, "Person", instance)
      association.instance.should == instance
    end

  end

  describe "#new" do

    context "when type is not valid" do

      it "raises an error" do
        lambda { Mongoloid::Association.new(:has_infinite, "Class", nil) }.should raise_error
      end

    end

  end

  describe "#type" do

    it "returns the association type defined in the constructor" do
      association = Mongoloid::Association.new(:has_many, "Person", Person.new)
      association.type.should == :has_many
    end

  end

end
