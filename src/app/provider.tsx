'use client';

import '@rainbow-me/rainbowkit/styles.css';
import {
    getDefaultConfig,
    RainbowKitProvider,
} from '@rainbow-me/rainbowkit';
import { WagmiProvider } from 'wagmi';
import {
    QueryClientProvider,
    QueryClient,
} from '@tanstack/react-query';

import {
    baseSepolia
} from 'wagmi/chains';
import { http } from 'wagmi';

const queryClient = new QueryClient();

const config = getDefaultConfig({
    appName: 'Lottery Game',
    projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID!,
    // eslint-disable-next-line  @typescript-eslint/no-explicit-any
    chains: [baseSepolia],
    ssr: true, // If your dApp uses server side rendering (SSR),
    transports: {
        [baseSepolia.id]: http(`https://base-sepolia.g.alchemy.com/v2/${process.env.NEXT_PUBLIC_ALCHEMY_KEY}`)
    }
});

export default function ContextProvider({ children }: { children: React.ReactNode }) {
    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider>
                    {children}
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider >
    );
}