pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "../contracts/RRUtils.sol";
import "../contracts/BytesUtils.sol";

contract TestRRUtils {
  using BytesUtils for *;
  using RRUtils for *;

  uint16 constant DNSTYPE_A = 1;
  uint16 constant DNSTYPE_CNAME = 5;
  uint16 constant DNSTYPE_MX = 15;
  uint16 constant DNSTYPE_TEXT = 16;
  uint16 constant DNSTYPE_RRSIG = 46;
  uint16 constant DNSTYPE_NSEC = 47;
  uint16 constant DNSTYPE_TYPE1234 = 1234;

  function testNameLength() public {
    Assert.equal(hex'00'.nameLength(0), 1, "nameLength('.') == 1");
    Assert.equal(hex'0361626300'.nameLength(4), 1, "nameLength('.') == 1");
    Assert.equal(hex'0361626300'.nameLength(0), 5, "nameLength('abc.') == 5");
  }

  function testLabelCount() public {
    Assert.equal(hex'00'.labelCount(0), 0, "labelCount('.') == 0");
    Assert.equal(hex'016100'.labelCount(0), 1, "labelCount('a.') == 1");
    Assert.equal(hex'016201610000'.labelCount(0), 2, "labelCount('b.a.') == 2");
    Assert.equal(hex'066574686c61620378797a00'.labelCount(6 +1), 1, "nameLength('(bthlab).xyz.') == 6");
  }

  function testIterateRRs() public {
    // a. IN A 3600 127.0.0.1
    // b.a. IN A 3600 192.168.1.1
    bytes memory rrs = hex'0161000001000100000e1000047400000101620161000001000100000e100004c0a80101';
    string[2] memory names = [hex'016100', hex'0162016100'];
    string[2] memory rdatas = [hex'74000001', hex'c0a80101'];
    uint i = 0;
    // Test failing with "TypeError: Member "done" not found " error
    for(RRUtils.RRIterator memory iter = rrs.iterateRRs(0); !iter.done(); iter.next()) {
      Assert.equal(uint(iter.dnstype), 1, "Type matches");
      Assert.equal(uint(iter.class), 1, "Class matches");
      Assert.equal(uint(iter.ttl), 3600, "TTL matches");
      Assert.equal(string(iter.name()), names[i], "Name matches");
      Assert.equal(string(iter.rdata()), rdatas[i], "Rdata matches");
      i++;
    }
    Assert.equal(i, 2, "Expected 2 records");
  }

  function testCheckTypeBitmapTextType() public {
    bytes memory tb = hex'0003000080';
    Assert.equal(tb.checkTypeBitmap(0, DNSTYPE_TEXT), true, "A record should exist in type bitmap");
  }

  function testCheckTypeBitmap() public {
    // From https://tools.ietf.org/html/rfc4034#section-4.3
    //    alfa.example.com. 86400 IN NSEC host.example.com. (
    //                               A MX RRSIG NSEC TYPE1234
    bytes memory tb = hex'FF0006400100000003041b000000000000000000000000000000000000000000000000000020';

    // Exists in bitmap
    Assert.equal(tb.checkTypeBitmap(1, DNSTYPE_A), true, "A record should exist in type bitmap");
    // Does not exist, but in a window that is included
    Assert.equal(tb.checkTypeBitmap(1, DNSTYPE_CNAME), false, "CNAME record should not exist in type bitmap");
    // Does not exist, past the end of a window that is included
    Assert.equal(tb.checkTypeBitmap(1, 64), false, "Type 64 should not exist in type bitmap");
    // Does not exist, in a window that does not exist
    Assert.equal(tb.checkTypeBitmap(1, 769), false, "Type 769 should not exist in type bitmap");
    // Exists in a subsequent window
    Assert.equal(tb.checkTypeBitmap(1, DNSTYPE_TYPE1234), true, "Type 1234 should exist in type bitmap");
    // Does not exist, past the end of the bitmap windows
    Assert.equal(tb.checkTypeBitmap(1, 1281), false, "Type 1281 should not exist in type bitmap");
  }

  bytes constant bthLabXyz = hex'066274686c61620378797a00';
  bytes constant ethLabXyz = hex'066574686c61620378797a00';
  bytes constant xyz = hex'0378797a00';
  bytes constant a_b_c  = hex'01610162016300';
  bytes constant b_b_c  = hex'01620162016300';
  bytes constant c      = hex'016300';
  bytes constant a_d_c  = hex'01610164016300';
  bytes constant b_a_c  = hex'01620161016300';
  bytes constant ab_c_d = hex'0261620163016400';
  bytes constant a_c_d  = hex'01610163016400';

  // Canonical ordering https://tools.ietf.org/html/rfc4034#section-6.1
  function testCompareLabelF() public {
    Assert.equal(xyz.compareLabel(ethLabXyz) < 0, true, "xyz comes before ethLab.xyz");
  }

  function testCompareLabelG() public {
    Assert.equal(bthLabXyz.compareLabel(ethLabXyz) < 0, true, "bthLab.xyz comes before ethLab.xyz");
  }

  function testCompareLabelH() public {
    Assert.equal(bthLabXyz.compareLabel(bthLabXyz) == 0, true, "bthLab.xyz and bthLab.xyz are the same");
  }

  function testCompareLabelI() public {
    Assert.equal(ethLabXyz.compareLabel(bthLabXyz) >  0, true, "ethLab.xyz comes after bethLab.xyz");
  }

  function testCompareLabelJ() public {
    Assert.equal(bthLabXyz.compareLabel(xyz)       >  0, true, "bthLab.xyz comes after xyz");
  }

  function testCompareLabelA() public {
    Assert.equal(a_b_c.compareLabel(c)      >  0, true, "one name has a difference of >1 label to the other");
  }

  function testCompareLabelB() public {
    Assert.equal(a_b_c.compareLabel(a_d_c)  <  0, true, "two names start the same but have differences in later labels");
  }

  function testCompareLabelC() public {
    Assert.equal(a_b_c.compareLabel(b_a_c)  >  0, true, "the first label sorts later, but the first label sorts earlier");
  }

  function testCompareLabelD() public {
    Assert.equal(ab_c_d.compareLabel(a_c_d) >  0, true, "two names where the first label on one is a prefix of the first label on the other");
  }

  function testCompareLabelE() public {
    Assert.equal(a_b_c.compareLabel(b_b_c)  <  0, true, "two names where the first label on one is a prefix of the first label on the other");
  }

}
