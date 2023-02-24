package simulation

//DONTCOVER

import (
	"fmt"
	"math/rand" //#nosec

	simtypes "github.com/cosmos/cosmos-sdk/types/simulation"
	"github.com/cosmos/cosmos-sdk/x/simulation"

	"github.com/classic-terra/core/x/feeshare/types"
)

// ParamChanges defines the parameters that can be modified by param change proposals
// on the simulation
func ParamChanges(r *rand.Rand) []simtypes.ParamChange {
	return []simtypes.ParamChange{
		simulation.NewSimParamChange(types.ModuleName, string(types.ParamStoreKeyEnableFeeShare),
			func(r *rand.Rand) string {
				return fmt.Sprintf("\"%v\"", GenEnableFeeShare(r))
			},
		),
		simulation.NewSimParamChange(types.ModuleName, string(types.ParamStoreKeyDeveloperShares),
			func(r *rand.Rand) string {
				return fmt.Sprintf("\"%d\"", GenDeveloperShares(r))
			},
		),
		simulation.NewSimParamChange(types.ModuleName, string(types.ParamStoreKeyAllowedDenoms),
			func(r *rand.Rand) string {
				return fmt.Sprintf("\"%s\"", GenAllowedDenoms(r))
			},
		),
	}
}
