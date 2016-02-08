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


  describe '.archives' do
    before do
      allow(TestModel).to receive(:min_time_between_archives).and_return(1)
    end

    it 'returns archives ordered newest first' do
      expect(TestModel.archives.count).to eq 0

      TestModel.archive!
      expect(TestModel.archives.count).to eq 1
      sleep 1

      TestModel.archive!
      expect(TestModel.archives.count).to eq 2

      expect(TestModel.archives[0].table_name > TestModel.archives[1].table_name).to be true
    end
  end


  describe '.and_archives' do
    describe 'when no archives exist' do
      it 'still lets you query the active class' do
        expect(TestModel.and_archives.count).to eq 1
        counts = (
          TestModel.and_archives.map do |klass|
            klass.count
          end
        )
        expect(counts).to eq([10])
      end
    end


    describe 'when archives exists' do
      it 'returns both the active class and archives' do
        TestModel.archive!
        expect(TestModel.and_archives.count).to eq 2
        counts = (
          TestModel.and_archives.map do |klass|
            klass.count
          end
        )
        expect(counts).to eq([0, 10])
      end


      describe 'when passed a specific number of archives' do
        before do
          allow(TestModel).to receive(:min_time_between_archives).and_return(1)
        end

        it 'only returns that many archives' do
          TestModel.archive!
          expect(TestModel.and_archives.count).to eq 2
          sleep(1)

          TestModel.archive!
          expect(TestModel.and_archives.count).to eq 3

          expect(TestModel.and_archives(1).count).to eq(2)
          expect(TestModel.and_archives.last.table_name < TestModel.and_archives(1).last.table_name).to be true
        end
      end
    end


    describe 'common patterns' do
      describe 'find a model by its unique ID' do
        it 'finds and returns a single instance from an active or archive table' do
          TestModel.archive!

          model = TestModel.and_archives.reduce(nil) do |acc, klass|
            acc ||= klass.find_by_id(5)
          end

          expect(model.is_a?(TestModel)).to be true
          expect(model.class).to_not eq TestModel
          expect(model.id).to eq 5

          last_model = TestModel.create(value: 'hi')

          model = TestModel.and_archives.reduce(nil) do |acc, klass|
            acc ||= klass.find_by_id(last_model.id)
          end

          expect(model.id).to eq(last_model.id)
        end
      end


      describe 'find and combine many models across active and archive tables' do
        it 'returns an array of results that can be combined or flattened' do
          TestModel.archive!
          TestModel.create(value: "abc in a fresh table")

          results = TestModel.and_archives.map do |klass|
            klass.where("value like '%abc%'")
          end

          expect(results.flatten.count).to eq(11)
        end
      end
    end
  end
end
