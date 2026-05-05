class FeeRules {
  static const int feeRateBasisPoints = 236; // 2% + 18% GST = 2.36%

  static int platformFee(int donationAmountPaise) {
    return ((donationAmountPaise * feeRateBasisPoints) / 10000).ceil();
  }
}
