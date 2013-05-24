=begin
Copyright (c) 2011 Litle & Co.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
=end
require_relative 'Configuration'
require 'net/sftp'

#
# This class handles sending the Litle Request (which is actually a series of batches!)
#

module LitleOnline
  class LitleRequest
    include XML::Mapping
    def initialize(options)
      #load configuration data
      @config_hash = Configuration.new.config
      @num_batch_requests = 0
      @path_to_request = ""
      @path_to_batches = ""
      @num_total_transactions = 0
      @MAX_NUM_TRANSACTIONS = 500000
      @options = options
    end

    # Creates the necessary files for the LitleRequest at the path specified. path/request_(TIMESTAMP) will be
    # the final XML markup and path/request_(TIMESTAMP) will hold intermediary XML markup
    # Params:
    # +path+:: A +String+ containing the path to the folder on disc to write the files to
    def create_new_litle_request(path)
      ts = Time::now.to_i.to_s
      ts += Time::now.nsec.to_s
      if(File.file?(path)) then
        raise RuntimeError, "Entered a file not a path."
      end

      if(path[-1,1] != '/' && path[-1,1] != '\\') then
        path = path + File::SEPARATOR
      end

      @path_to_request = path + 'request_' + ts
      @path_to_batches = @path_to_request + '_batches'

      if File.file?(@path_to_request) or File.file?(@path_to_batches) then
        create_new_litle_request(path)
      return
      end

      File.open(@path_to_request, 'a+') do |file|
        file.write("")
      end
      File.open(@path_to_batches, 'a+') do |file|
        file.write("")
      end
    end

    # Adds a batch to the LitleRequest. If the batch is open when passed, it will be closed prior to being added.
    # Params:
    # +arg+:: a +LitleBatchRequest+ containing the transactions you wish to send or a +String+ specifying the
    # path to the batch file
    def commit_batch(arg)
      path_to_batch = ""
      #they passed a batch
      if arg.kind_of?(LitleBatchRequest) then
        path_to_batch = arg.get_batch_name
      elsif arg.kind_of?(String) then
        path_to_batch = arg
      else
        raise RuntimeError, "You entered neither a path nor a batch. Game over :("
      end
      #the batch isn't closed. let's help a brother out
      if (ind = path_to_batch.index(/\.closed/)) == nil then
        puts 'We received a path of a batch that was not closed: ' + path_to_batch
        if arg.kind_of?(String) then
          new_batch = LitleBatchRequest.new
        new_batch.open_existing_batch(path_to_batch)
        new_batch.close_batch()
        path_to_batch = new_batch.get_batch_name
        elsif arg.kind_of?(LitleBatchRequest) then
        arg.close_batch()
        path_to_batch = arg.get_batch_name
        end
        ind = path_to_batch.index(/\.closed/)
      end
      transactions_in_batch = path_to_batch[ind+8..path_to_batch.length].to_i

      # if the litle request would be too big, let's make another!
      if (@num_total_transactions + transactions_in_batch) > @MAX_NUM_TRANSACTIONS then
        finish_request
        initialize(@options)
        create_new_litle_request
      else #otherwise, let's add it line by line to the request doc
        @num_batch_requests += 1
        @num_total_transactions += transactions_in_batch

        puts "At location " + @path_to_batches + " we are writing the file from " + path_to_batch
        File.open(@path_to_batches, 'a+') do |fo|
          File.foreach(path_to_batch) do |li|
            fo.puts li
          end
        end
        
        File.delete(path_to_batch)
      end
    end

    # FTPs all previously unsent LitleRequests located in the folder denoted by path to the server
    # Params:
    # +path+:: A +String+ containing the path to the folder on disc where LitleRequests are located.
    # This should be the same location where the LitleRequests were written to.
    def send_to_litle(path = (File.dir_name(@path_to_batches)))
      #finish off what we're working on
      finish_request()
      
      Net::SFTP.start('cert1.litle.com:30438', 'PHXMLTEST', :password => 'password') do |stfp|
        
        # our folder is /SHORTNAME/SHORTNAME/INBOUND
        Dir.foreach(path) do |filename| {
          #we have a complete report according to filename regex
          if((filename =~ /request_\d\.complete/) != nil) then
            # adding .prg extension per the XML 
            File.rename(filename, filename + '.prg')
            # upload the file
            sftp.upload!(filename + '.prg', '/'+ filename+'.prg')
            # rename now that we're done
            sftp.rename!('/'+ filename+'.prg', '/'+ filename+'.asc')
            
            #INSERT LITLE MAGIC HERE
          end
          
          #TODO: Check the behavior of the cert server with a large batch or two. If the more complicated
          # transactions still return an immediate preliminary response, we should now poll the remote destination
          # every thirty seconds or so to check whether we've gotten a batch response back yet. The XML doc says
          # that a response should be available within 10 minutes, but this spec definitely needs to be verified
          
          # otherwise, we need to figure out how we're handling checking for responses. It should be noted that
          # the XML doc states that old repsonses will be cleared from the merchant's dir 24 hours after they
          # were loaded.
        }
      end
    end

    def get_path_to_batches
      return @path_to_batches
    end

    # Called when you wish to finish adding batches to your request, this method rewrites the aggregate
    # batch file to the final LitleRequest xml doc with the appropos LitleRequest tags.
    def finish_request
      
      File.open(@path_to_request, 'w') do |f|
        #jam dat header in there
        f.puts(build_request_header())
        #read into the request file from the batches file
        File.foreach(@path_to_batches) do |li|
          f.puts li
        end
        #finally, let's poot in a header, for old time's sake
        f.puts '</litleRequest>'
      end

      #rename the requests file
      File.rename(@path_to_request, @path_to_request + '.complete')
      #we don't need the master batch file anymore
      File.delete(@path_to_batches)
    end

    private

    def build_request_header(options = @options)
      litle_request = self

      authentication = Authentication.new
      authentication.user = get_config(:user, options)
      authentication.password = get_config(:password, options)

      litle_request.authentication = authentication
      litle_request.version         = '8.16'
      litle_request.xmlns           = "http://www.litle.com/schema"
      # litle_request.id              = options['sessionId'] #grab from options; okay if nil
      litle_request.numBatchRequests = @num_batch_requests

      xml = litle_request.save_to_xml.to_s
      xml[/<\/litleRequest>/]=''
      return xml
    end

    def get_config(field, options)
      options[field.to_s] == nil ? @config_hash[field.to_s] : options[field.to_s]
    end
  end
end