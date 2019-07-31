from os import environ
import json

class Config:
    agent_root = 'agent'
    skale_ima_root = 'npms/skale-mta'
    proxy_root = 'proxy'
    network_for_mainnet = 'mainnet'
    network_for_schain = 'schain'
    mainnet_key=''
    mainnet_rpc_url='http://localhost:8545'
    schain_key = ''
    schain_rpc_url = 'http://localhost:8545'
    schain_name = 'd2'

    def __init__(self, src_root, config_filename):
        self.proxy_root = src_root + '/' + self.proxy_root
        self.agent_root = src_root + '/' + self.agent_root
        self.skale_ima_root = src_root + '/' + self.skale_ima_root
        with open(config_filename, 'r') as config_file:
            config_json = json.load(config_file)
            self.network_for_mainnet = config_json['NETWORK_FOR_MAINNET']
            self.network_for_schain = config_json['NETWORK_FOR_SCHAIN']
            self.mainnet_key = config_json['ETH_PRIVATE_KEY_FOR_MAINNET']
            self.mainnet_rpc_url = config_json['MAINNET_RPC_URL']
            self.schain_key = config_json['ETH_PRIVATE_KEY_FOR_SCHAIN']
            self.schain_rpc_url = config_json['SCHAIN_RPC_URL']
            self.schain_name = config_json['SCHAIN_NAME']

