import requests
import MISP2Sentinel.config as config
import datetime
import os
import json
import copy
import hashlib
from MISP2Sentinel.constants import *
import time
import logging


class RequestManager:
    """A class that handles submitting TiIndicators to MS Graph Security API

    to use the class:
        with RequestManager() as request_manager:
            request_manager.handle_indicator(tiindicator)

    """

    RJUST = 5

    def __init__(self, total_indicators, tenant):
        self.total_indicators = total_indicators
        self.tenant = tenant

    def __enter__(self):
        try:
            self.existing_indicators_hash_fd = open(EXISTING_INDICATORS_HASH_FILE_NAME+self.tenant+".json", 'r+')
            self.existing_indicators_hash = json.load(self.existing_indicators_hash_fd)
        except (FileNotFoundError, json.decoder.JSONDecodeError):
            self.existing_indicators_hash_fd = open(EXISTING_INDICATORS_HASH_FILE_NAME+self.tenant+".json", 'w')
            self.existing_indicators_hash = {}
        try:
            self.expiration_date_fd = open(EXPIRATION_DATE_FILE_NAME+self.tenant+".txt", 'r+')
            self.expiration_date = self.expiration_date_fd.read()
        except FileNotFoundError:
            self.expiration_date_fd = open(EXPIRATION_DATE_FILE_NAME+self.tenant+".txt", 'w')
            self.expiration_date = self._get_expiration_date_from_config()
        if self.expiration_date <= datetime.datetime.utcnow().strftime('%Y-%m-%d'):
            logging.info("----------------CLEAR existing_indicators_hash---------------------------")
            self.existing_indicators_hash = {}
            self.expiration_date = self._get_expiration_date_from_config()
        self.hash_of_indicators_to_delete = copy.deepcopy(self.existing_indicators_hash)
        access_token = self._get_access_token(
            config.ms_auth[TENANT],
            config.ms_auth[CLIENT_ID],
            config.ms_auth[CLIENT_SECRET],
            config.ms_auth[SCOPE])
        self.headers = {"Authorization": f"Bearer {access_token}", "user-agent": config.ms_useragent, "content-type": "application/json"}
        self.headers_expiration_time = self._get_timestamp() + 3500
        self.success_count = 0
        self.error_count = 0
        self.del_count = 0
        self.indicators_to_be_sent = []
        self.indicators_to_be_sent_size = 0
        self.start_time = self.last_batch_done_timestamp = self._get_timestamp()
        if not os.path.exists(LOG_DIRECTORY_NAME):
            os.makedirs(LOG_DIRECTORY_NAME)
        return self

    @staticmethod
    def _get_expiration_date_from_config():
        return (datetime.datetime.utcnow() + datetime.timedelta(config.days_to_expire)).strftime('%Y-%m-%d')

    @staticmethod
    def _get_access_token(tenant, client_id, client_secret, scope):
        data = {
            CLIENT_ID: client_id,
            'scope': scope,
            CLIENT_SECRET: client_secret,
            'grant_type': 'client_credentials'
        }
        access_token = requests.post(
            f'https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token',
            data=data
        ).json()[ACCESS_TOKEN]
        return access_token

    @staticmethod
    def read_tiindicators():
        access_token = RequestManager._get_access_token(
                config.ms_auth[TENANT],
                config.ms_auth[CLIENT_ID],
                config.ms_auth[CLIENT_SECRET],
                config.ms_auth[SCOPE])

        res = requests.get(
            GRAPH_TI_INDICATORS_URL,
            headers={"Authorization": f"Bearer {access_token}"}
            ).json()
        if config.verbose_log:
            logging.debug(json.dumps(res, indent=2))

    @staticmethod
    def _get_request_hash(request):
        return hashlib.sha256(
            json.dumps(
                {
                    k: v for k, v in request.items()
                    if k not in ("expirationDateTime", "lastReportedDateTime")
                },
                sort_keys=True,
            ).encode("utf-8")
        ).hexdigest()
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        '''This function is called when the context manager is exited
        '''

    def _log_post(self, response):
        # self._clear_screen()
        cur_batch_success_count = cur_batch_error_count = 0
        if config.verbose_log:
            logging.debug(f"response: {response}")

        if 'error' in response:
            self.error_count += 1
            cur_batch_error_count += 1
            file_name = f"{self._get_datetime_now()}_error.json"
            log_file_name = file_name.replace(':', '')
            with open(f'{LOG_DIRECTORY_NAME}/{log_file_name}', 'w') as file:
                json.dump(response['error'], file)
        else:
            if len(response['value']) > 0:
                for value in response['value']:
                    if "Error" in value:
                        self.error_count += 1
                        cur_batch_error_count += 1
                        file_name = f"{self._get_datetime_now()}_error_{value[INDICATOR_REQUEST_HASH]}.json"
                        log_file_name = file_name.replace(':', '')
                        with open(f'{LOG_DIRECTORY_NAME}/{log_file_name}', 'w') as file:
                            json.dump(value, file)
                    else:
                        self.success_count += 1
                        cur_batch_success_count += 1
                        self.existing_indicators_hash[value[INDICATOR_REQUEST_HASH]] = value['id']
                        # if not config.verbose_log:
                        #     continue
                        file_name = f"{self._get_datetime_now()}_{value[INDICATOR_REQUEST_HASH]}.json"
                        log_file_name = file_name.replace(':', '')
                        if config.write_post_json:
                            with open(f'{LOG_DIRECTORY_NAME}/{log_file_name}', 'w') as file:
                                json.dump(value, file)
            else:
                file_name = f"{self._get_datetime_now()}.json"
                log_file_name = file_name.replace(':', '')
                if config.write_post_json:
                    with open(f'{LOG_DIRECTORY_NAME}/{log_file_name}', 'w') as file:
                        json.dump(response, file)

        if config.ms_auth["graph_api"]:
            logging.info('sending security indicators to Microsoft Graph Security\n')
            logging.info(f'{self.total_indicators} indicators are parsed from misp events. Only those that do not exist in Microsoft Graph Security will be sent.\n')
        else:
            logging.info(f'{self.total_indicators} indicators are parsed from misp events. \n')
        cur_batch_took = self._get_timestamp() - self.last_batch_done_timestamp
        self.last_batch_done_timestamp = self._get_timestamp()
        logging.info(f'current batch took:   {round(cur_batch_took, 2):{6}} seconds')

    @staticmethod
    def _get_datetime_now():
        return str(datetime.datetime.now()).replace(' ', '_')

    def _del_indicators_no_longer_exist(self):
        indicators = list(self.hash_of_indicators_to_delete.values())
        self.del_count = len(indicators)
        for i in range(0, len(indicators), 100):
            request_body = {'value': indicators[i: i+100]}
            if config.verbose_log:
                logging.debug(request_body)
            response = requests.post(GRAPH_BULK_DEL_URL, headers=self.headers, json=request_body).json()
            file_name = f"del_{self._get_datetime_now()}.json"
            log_file_name = file_name.replace(':', '')
            if config.write_post_json:
                json.dump(response, open(f'{LOG_DIRECTORY_NAME}/{log_file_name}', 'w'), indent=2)
        for hash_of_indicator_to_delete in self.hash_of_indicators_to_delete.keys():
            self.existing_indicators_hash.pop(hash_of_indicator_to_delete, None)

    def _print_summary(self):
        logging.info('script finished running\n')
        logging.info(f"total indicators sent:    {str(self._get_total_indicators_sent()).rjust(self.RJUST)}")
        logging.info(f"total response success:   {str(self.success_count).rjust(self.RJUST)}")
        logging.info(f"total response error:     {str(self.error_count).rjust(self.RJUST)}")
        logging.info(f"total indicators deleted: {str(self.del_count).rjust(self.RJUST)}")

    def _post_to_graph(self):
        request_body = {'value': self.indicators_to_be_sent}
        response = requests.post(GRAPH_BULK_POST_URL, headers=self.headers, json=request_body).json()
        self.indicators_to_be_sent = []
        self._log_post(response)

    def upload_indicators(self, parsed_indicators):
        requests_number = 0
        start_timestamp = self._get_timestamp()
        while len(parsed_indicators) > 0:
            if requests_number >= config.ms_max_requests_minute:
                sleep_time = 102 - (self._get_timestamp() - start_timestamp)
                if sleep_time > 0:
                    logging.debug("Pausing upload for API request limit {}".format(sleep_time))
                    time.sleep(sleep_time)
                requests_number = 0
                start_timestamp = self._get_timestamp()

            self._update_headers_if_expired()
            workspace_id = config.ms_auth["workspace_id"]
            request_url = f"https://sentinelus.azure-api.net/{workspace_id}/threatintelligence:upload-indicators?api-version=2022-07-01"
            request_body = {"sourcesystem": "MISP", "value": parsed_indicators[:config.ms_max_indicators_request]}
            response = requests.post(request_url, headers=self.headers, json=request_body)
            if response.status_code == 200:
                if "errors" in response.json() and len(response.json()["errors"]) > 0:
                    logging.error("Error when submitting indicators. {}".format(response.text))
                    break
                else:
                    logging.info("Indicators sent - request number: {} / indicators: {}".format(requests_number, len(request_body["value"])))
                    parsed_indicators = parsed_indicators[config.ms_max_indicators_request:]
                    requests_number += 1
            else:
                logging.error("Error when submitting indicators. {}".format(response.text))
                break

    def handle_indicator(self, indicator):
        self._update_headers_if_expired()
        indicator[EXPIRATION_DATE_TIME] = self.expiration_date
        indicator_hash = self._get_request_hash(indicator)
        indicator[INDICATOR_REQUEST_HASH] = indicator_hash
        self.hash_of_indicators_to_delete.pop(indicator_hash, None)
        if indicator_hash not in self.existing_indicators_hash:
            self.indicators_to_be_sent.append(indicator)
        if len(self.indicators_to_be_sent) >= 100:
            logging.info(f"number of indicators sent: {self.success_count+self.error_count}")
            self._post_to_graph()

    def _update_headers_if_expired(self):
        if self._get_timestamp() > self.headers_expiration_time:
            access_token = self._get_access_token(
                config.ms_auth[TENANT],
                config.ms_auth[CLIENT_ID],
                config.ms_auth[CLIENT_SECRET],
                config.ms_auth[SCOPE])
            self.headers = {"Authorization": f"Bearer {access_token}", "user-agent": config.ms_useragent, "content-type": "application/json"}
            logging.debug(access_token)

    @staticmethod
    def _clear_screen():
        if os.name == 'posix':
            os.system('clear')
        else:
            os.system('cls')

    @staticmethod
    def _get_timestamp():
        return datetime.datetime.now().timestamp()

    def _get_total_indicators_sent(self):
        return self.error_count + self.success_count