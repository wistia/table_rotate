module TableRotate
  class Error < StandardError; end
  class NotEnoughTimeBetweenArchivesError < Error; end
  class InvalidTimestampError < Error; end
  class ArchiveTableAlreadyExistsError < Error; end
end
