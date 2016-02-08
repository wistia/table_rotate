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


    describe 'when we have reached max_archive_count' do
      before do
        allow(TestModel).to receive(:max_archive_count).and_return(2)
        allow(TestModel).to receive(:min_time_between_archives).and_return(1)
      end

      describe 'when archive! is called again' do
        it 'drops the oldest table' do
          expect(TestModel.archives.count).to eq 0

          TestModel.archive!
          expect(TestModel.archives.count).to eq 1
          sleep 1

          TestModel.archive!
          expect(TestModel.archives.count).to eq 2
          sleep 1

          TestModel.archive!
          expect(TestModel.archives.count).to eq 2
        end
      end
    end


    describe 'when archive is called before min_time_between_archives has elapsed' do
      it 'raises an exception' do
        TestModel.archive!
        expect{ TestModel.archive! }.to raise_error(TableRotate::NotEnoughTimeBetweenArchivesError)
      end
    end
  end
end
