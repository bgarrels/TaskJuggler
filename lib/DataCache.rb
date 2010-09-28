#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DataCache.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'time'
require 'singleton'

class TaskJuggler

  # These are the entries in the DataCache. They store a value and an access
  # counter. The counter can be read and written externally.
  class DataCacheEntry

    attr_accessor :hits

    # Create a new DataCacheEntry for the _value_. The access counter is set
    # to 1 to increase the chance that it is not flushed immedidate.
    def initialize(value)
      @value = value
      @hits = 1
    end

    # Return the value and increase the access counter by 1.
    def value
      @hits += 1
      @value
    end

  end

  # This class provides a global data cache that can be used to store and
  # retrieve values indexed by a key. The cache is size limited. When maximum
  # capacity is reached, a certain percentage of the least requested values is
  # dropped from the cache. The primary purpose of this global cache is to
  # store values that are expensive to compute but may be need on several
  # occasions during the program execution.
  class DataCache

    include Singleton

    def initialize
      resize
      flush
      # Counter for the number of writes to the cache.
      @stores = 0
      # Counter for the number of found values.
      @hits = 0
      # Counter for the number of not found values.
      @misses = 0
    end

    # For now, we use this randomly determined size.
    def resize(size = 100000)
      @highWaterMark = size
      # Flushing out the least used entries is fairly expensive. So we only
      # want to do this once in a while. The lowWaterMark determines how much
      # of the entries will survive the flush.
      @lowWaterMark = size * 0.9
    end

    # Completely flush the cache. The statistic counters will remain intact,
    # but all data values are lost.
    def flush
      @entries = {}
    end

    # Store _value_ into the cache using _key_ to tag it. _key_ must be unique
    # and must be used to load the value from the cache again. You cannot
    # store nil values!
    def store(value, key)
      @stores += 1
      # If the cache has reached the specified high water mark, we throw out
      # old values.
      if @entries.size > @highWaterMark
        while @entries.size > @lowWaterMark
          # How many entries do we need to delete to get to the low watermark?
          toDelete = @entries.size - @lowWaterMark
          @entries.delete_if do |key, e|
            # Hit counts age with every cleanup.
            (e.hits -= 1) < 0 && (toDelete -= 1) >= 0
          end
        end
      end

      @entries[key] = DataCacheEntry.new(value)

      value
    end

    # Retrieve the value indexed by _key_ from the cache. If it's not found,
    # nil is returned.
    def load(key)
      if (e = @entries[key])
        @hits += 1
        e.value
      else
        @misses += 1
        nil
      end
    end

    def to_s
      <<"EOT"
Entries: #{@entries.size}   Stores: #{@stores}
Hits: #{@hits}   Misses: #{@misses}
Hit Rate: #{@hits * 100.0 / (@hits + @misses)}%
EOT
    end

  end

end

