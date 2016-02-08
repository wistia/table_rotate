require 'spec_helper'

describe TableRotate do
  before do
    establish_db_connection!
    reset_tables!

    (0...10).map do |i|
      TestModel.create(value: "abc #{i}")
    end
  end


  describe '.archive!' do
    it 'clears out the model and creates a new table with its entries' do
      expect(TestModel.count).to eq 10
      expect(TableRotate.show_tables.count).to eq 1
      expect(TestModel.archives.count).to eq 0

      TestModel.archive!

      expect(TableRotate.show_tables.count).to eq 2
      expect(TestModel.count).to eq 0
      expect(TestModel.archives.count).to eq 1
      expect(TestModel.archives.first.count).to eq 10
    end


    describe 'when new entries are inserted afterward' do
      it 'they appear in TestModel' do
        TestModel.archive!
        TestModel.create(value: 'hello')
        TestModel.create(value: 'hello again')
        expect(TestModel.archives.count).to eq 1
        expect(TestModel.archives.first.count).to eq 10
        expect(TestModel.count).to eq 2
      end
    end
  end
end
