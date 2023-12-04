#--
#   Copyright (C) 2002, 2003 Matt Armstrong.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
# NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#++
# Implements the RMail::Utils module.

require "base64"
require "./quoted_printable"

module RMail

  # The RMail::Utils module is a collection of random utility methods
  # that are useful for dealing with email.
  module Utils

    extend self

    # Return the given string unquoted if it is quoted.
    def unquote(str : String)
      if str =~ /\s*"(.*?([^\\]|\\\\))"/m
	$1.gsub(/\\(.)/, "\1")
      else
	str
      end
    end

    # Decode the given string as if it were a chunk of base64 data
    def base64_decode(str : String)
      #str.unpack("m*").first
      Base64.decode_string(str)
    end

    # Decode the given string as if it were a chunk of quoted
    # printable data
    def quoted_printable_decode(str : String)
      #str.unpack("M*").first
      RMail::QuotedPrintable.decode_string(str)
    end

  end
end
