package market

import (
	sdk "github.com/cosmos/cosmos-sdk/types"
)

// Oracle errors reserve 1101-1199
const (
	DefaultCodespace sdk.CodespaceType = "MARKET"

	CodeInsufficientSwap sdk.CodeType = 1
	CodeUnknownDenom     sdk.CodeType = 2
	CodeRecursiveSwap    sdk.CodeType = 3
)

// ----------------------------------------
// Error constructors

// ErrUnknownDenomination called when the signer of a Msg is not a validator
func ErrUnknownDenomination(codespace sdk.CodespaceType, denom string) sdk.Error {
	return sdk.NewError(codespace, CodeUnknownDenom, "Unknown denom in SwapMsg: "+denom)
}

// ErrInsufficientSwapCoins called when not enough coins are being requested for a swap
func ErrInsufficientSwapCoins(codespace sdk.CodespaceType, rval sdk.Int) sdk.Error {
	return sdk.NewError(codespace, CodeInsufficientSwap, "Not enough coins for a swap: "+rval.String())
}

// ErrRecursiveSwap called when Ask and Offer coin denominatioins are equal
func ErrRecursiveSwap(codespace sdk.CodespaceType, denom string) sdk.Error {
	return sdk.NewError(codespace, CodeRecursiveSwap, "Can't swap tokens with the same denomination: "+denom)
}
