require "./spec_helper"
require "../src/rfc2047"

def test(comment : String, s : String, expected : String)
  describe Rfc2047 do
    it "decodes a #{comment}" do
      decoded = Rfc2047.decode_to("UTF-8", s)
      decoded.should eq(expected)
    end
  end
end


# The following examples were taken from:
# https://datatracker.ietf.org/doc/html/rfc2047
test "example #1 from RFC-2047",
     "To: =?ISO-8859-1?Q?Keld_J=F8rn_Simonsen?= <keld@dkuug.dk>",
     "To: Keld Jørn Simonsen <keld@dkuug.dk>"
test "example #2 from RFC-2047",
     "Subject: =?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?=\r\n  =?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=",
     "Subject: \x01u understand the example."
test "example #3 from RFC-2047",
     "(=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)",
     "(םולש ןב ילטפנ)"
test "example #4 from RFC-2047",
     "=?ISO-8859-1?Q?Andr=E9?= Pirard <PIRARD@vm1.ulg.ac.be>",
     "André Pirard <PIRARD@vm1.ulg.ac.be>"

# The following example was taken from:
# https://shallowsky.com/blog/programming/decoding-email-headers.html
test "spammer example",
     "Subject: =?utf-8?B?U3RvcCBPdmVycGF5aW5nIGZvciBQcmludGVyIEluaw==?=",
     "Subject: Stop Overpaying for Printer Ink"

# The following examples were taken from:
# https://search.r-project.org/CRAN/refmans/mRpostman/html/decode_mime_header.html
test "Portuguese example #1",
      "=?iso-8859-1?Q?Minist=E9rio_da_Educa=E7=E3o?=",
      "Ministério da Educação"
test "French example",
     "=?UTF-8?Q?sur la route =C3=A0 suivre les voil=C3=A0 bient=C3=B4t qui te d=C3=A9gradent?=",
     "sur la route à suivre les voilà bientôt qui te dégradent"
test "Portuguese example #2",
     "=?iso-8859-1?Q?DIDEC_Capacita=E7=E3o?=",
     "DIDEC Capacitação"
test "German example",
     "=?UTF-8?Q?stern=2Ede_-_t=C3=A4glich?=",
     "stern.de - täglich"
test "Portuguese example #3",
     "=?utf-8?B?Sk9BTkEgRlVTQ08gTE9CTyBubyBUZWFtcw==?=",
     "JOANA FUSCO LOBO no Teams"
