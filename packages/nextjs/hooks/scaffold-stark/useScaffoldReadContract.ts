import { Abi, useReadContract } from "@starknet-react/core";
import { BlockNumber } from "starknet";
import { useDeployedContractInfo } from "~~/hooks/scaffold-stark";
import {
    AbiFunctionOutputs,
    ContractAbi,
    ContractName,
    ExtractAbiFunctionNamesScaffold,
    UseScaffoldReadConfig,
} from "~~/utils/scaffold-stark/contract";

export const useScaffoldReadContract = <
    TAbi extends Abi,
    TContractName extends ContractName,
    TFunctionName extends ExtractAbiFunctionNamesScaffold<ContractAbi<TContractName>, "view">,
>({
    contractName,
    functionName,
    args,
    ...readConfig
}: UseScaffoldReadConfig<TAbi, TContractName, TFunctionName>) => {
    const { data: deployedContract } = useDeployedContractInfo(contractName);

    const result = useReadContract({
        functionName,
        address: deployedContract?.address,
        abi: deployedContract?.abi,
        args: args || [],
        blockIdentifier: "pending" as BlockNumber,
        ...readConfig,
    });

    if (result.data && Array.isArray(result.data)) {
        const processedData = result.data.map((item: any) =>
            typeof item === "bigint" ? `0x${item.toString(16)}` : item
        );
        return { ...result, data: processedData };
    }

    return result as Omit<ReturnType<typeof useReadContract>, "data"> & {
        data: AbiFunctionOutputs<ContractAbi<TContractName>, TFunctionName> | undefined;
    };
};
