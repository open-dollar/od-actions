<p align="center">
<img width="60" height="60"  src="https://raw.githubusercontent.com/open-dollar/.github/main/od-logo.svg">
</p>
<h1 align="center">
  Open Dollar
</h1>

<p align="center">
  <a href="https://twitter.com/open_dollar" target="_blank">
    <img alt="Twitter: open_dollar" src="https://img.shields.io/twitter/follow/open_dollar.svg?style=social" />
  </a>
</p>

Template for projects using `@opendollar/contracts` with Foundry

## Documentation

- https://book.getfoundry.sh/
- https://contracts.opendollar.com
- https://docs.opendollar.com

## ParaswapSellAdapter Docs

### get max loan and leveraged amount of debt:

IParaswapSellAdapter.getLeveragedDebt(bytes32 _cType, uint256 _initCapital)

### get loan and leveraged amount of debt with percentage buffer:

IParaswapSellAdapter.getLeveragedDebt(bytes32 _cType, uint256 _initCapital, uint256 _percentageBuffer)

### execute leverage flashloan

IParaswapSellAdapter.requestFlashloan(SellParams memory _sellParams, uint256 _initCollateral, uint256 _collateralLoan, uint256 _minDstAmount, uint256 _safeId, bytes32 _cType)