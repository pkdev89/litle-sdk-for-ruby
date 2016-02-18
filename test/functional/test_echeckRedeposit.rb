=begin
Copyright (c) 2012 Litle & Co.

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
require File.expand_path("../../../lib/LitleOnline",__FILE__) 
require 'test/unit'

module LitleOnline
  class Test_echeckRedeposit < Test::Unit::TestCase
    def test_simple_echeck_redeposit
      hash = {
        'merchantId' => '101',
        'version'=>'8.8',
        'id'=>'test',
        'reportGroup'=>'Planets',
        'litleTxnId'=>'123456'
      }
      response= LitleOnlineRequest.new.echeck_redeposit(hash)
      assert_equal('Valid Format', response.message)
    end
  
    def test_echeck_redeposit_with_echeck
      hash = {
        'merchantId' => '101',
        'version'=>'8.8',
        'id'=>'test',
        'reportGroup'=>'Planets',
        'litleTxnId'=>'123456',
        'echeck' => {'accType'=>'Checking','accNum'=>'12345657890','routingNum'=>'123456789','checkNum'=>'123455'}
      }
      response= LitleOnlineRequest.new.echeck_redeposit(hash)
      assert_equal('Valid Format', response.message)
    end
  
    def test_echeck_redeposit_with_echeck_token
      hash = {
        'merchantId' => '101',
        'version'=>'8.8',
        'id'=>'test',
        'reportGroup'=>'Planets',
        'litleTxnId'=>'123456',
        'echeckToken' => {'accType'=>'Checking','litleToken'=>'1234565789012','routingNum'=>'123456789','checkNum'=>'123455'}
      }
      response= LitleOnlineRequest.new.echeck_redeposit(hash)
      assert_equal('Valid Format', response.message)
    end
  
    def test_extra_field_and_incorrect_order
      hash = {
        'merchantId' => '101',
        'version'=>'8.8',
        'id'=>'test',
        'reportGroup'=>'Planets',
        'invalidfield'=>'nonexistant',
        'echeck' => {'accType'=>'Checking','accNum'=>'12345657890','routingNum'=>'123456789','checkNum'=>'123455'},
        'litleTxnId'=>'123456'
      }
      response= LitleOnlineRequest.new.echeck_redeposit(hash)
      assert_equal('Valid Format', response.message)
    end
  
    def test_no_txn_id
      hash = {
        'merchantId' => '101',
        'version'=>'8.8',
        'reportGroup'=>'Planets',
      }
      response= LitleOnlineRequest.new.echeck_redeposit(hash)
      assert(response.message =~ /Error validating xml data against the schema/)
    end
  end
end