

from flask import Flask, render_template, request, jsonify
import telebot
from loguru import logger
import os
import time
from telebot.types import InputFile
from img_proc import Img
import boto3


queue_name = 'loay-PolybotServiceQueue-tf'
sqs_client = boto3.client('sqs', region_name='eu-west-3')
images_bucket = os.environ['BUCKET_NAME']

class Bot:
    def __init__(self, token, telegram_chat_url):
        self.telegram_bot_client = telebot.TeleBot(token)
        self.telegram_bot_client.remove_webhook()
        time.sleep(0.5)
        retries = 4
        for _ in range(retries):
            try:
                #self.telegram_bot_client.set_webhook(url=f'{telegram_chat_url}/{token}/', timeout=60)
                # with open("/usr/src/app/YOURPUBLIC.pem", 'r') as cert:
                #     self.telegram_bot_client.set_webhook(url=f'{telegram_chat_url}/{token}/', certificate=cert, timeout=60)
                logger.info(f'Setting webhook to: {f"{telegram_chat_url}/{token}/"}')
                self.telegram_bot_client.set_webhook(url=f'{telegram_chat_url}/{token}/', timeout=60)
                logger.info(f'Telegram Bot information\n\n{self.telegram_bot_client.get_me()}')
                break  # Break out of the retry loop if successful
            except telebot.apihelper.ApiTelegramException as e:
                if e.error_code == 429:  # Too Many Requests error
                    retry_after = int(e.result_json.get('parameters', {}).get('retry_after', 1))
                    logger.warning(f"Too Many Requests. Retrying after {retry_after} seconds...")
                    time.sleep(retry_after)
                    continue
                else:
                    raise e  # Re-raise the exception if it's not a 429 error
        else:
            logger.error("Failed to set webhook after retries")

    def send_text(self, chat_id, text):
        self.telegram_bot_client.send_message(chat_id, text)

    def send_text_with_quote(self, chat_id, text, quoted_msg_id):
        self.telegram_bot_client.send_message(chat_id, text, reply_to_message_id=quoted_msg_id)

    def is_current_msg_photo(self, msg):
        return 'photo' in msg

    def download_user_photo(self, msg):
        """
        Downloads the photos that sent to the Bot to `photos` directory (should be existed)
        :return:
        """
        if not self.is_current_msg_photo(msg):
            raise RuntimeError(f'Message content of type \'photo\' expected')

        file_info = self.telegram_bot_client.get_file(msg['photo'][-1]['file_id'])
        data = self.telegram_bot_client.download_file(file_info.file_path)
        folder_name = file_info.file_path.split('/')[0]

        if not os.path.exists(folder_name):
            os.makedirs(folder_name)

        with open(file_info.file_path, 'wb') as photo:
            photo.write(data)

        return file_info.file_path

    def send_photo(self, chat_id, img_path):
        if not os.path.exists(img_path):
            raise RuntimeError("Image path doesn't exist")

        self.telegram_bot_client.send_photo(
            chat_id,
            InputFile(img_path)
        )

    def handle_message(self, msg):
        """Bot Main message handler"""
        logger.info(f'Incoming message: {msg}')
        self.send_text(msg['chat']['id'], f'Your original message: {msg["text"]}')


class ObjectDetectionBot(Bot):
    def handle_message(self, msg):

        logger.info(f'Incoming message: {msg}')

        
        if "caption" in msg :
            try:
                photo_path = self.download_user_photo(msg)
                

                if msg["caption"] == "Blur":
                    self.send_text(msg['chat']['id'], "Blur filter in progress")
                    new_img = Img(photo_path)
                    new_img.blur()
                    new_path = new_img.save_img()
                    self.send_photo(msg["chat"]["id"], new_path)
                    self.send_text(msg['chat']['id'], "Blur filter applied")
                elif msg["caption"] == "Contour":
                    self.send_text(msg['chat']['id'], "Contour filter in progress")
                    new_img = Img(photo_path)
                    new_img.contour()
                    new_path = new_img.save_img()
                    self.send_photo(msg["chat"]["id"], new_path)
                    self.send_text(msg['chat']['id'], "Contour filter applied")
                elif msg["caption"] == "Salt and pepper":
                    self.send_text(msg['chat']['id'], "Salt and pepper filter in progress")
                    new_img = Img(photo_path)
                    new_img.salt_n_pepper()
                    new_path = new_img.save_img()
                    self.send_photo(msg["chat"]["id"], new_path)
                    self.send_text(msg['chat']['id'], "Salt and pepper filter applied")
                elif msg["caption"] == "rotate":
                    self.send_text(msg['chat']['id'], "rotate filter in progress")
                    new_img = Img(photo_path)
                    new_img.rotate()
                    new_path = new_img.save_img()
                    self.send_photo(msg["chat"]["id"], new_path)
                    self.send_text(msg['chat']['id'], "rotate filter applied")
                elif msg["caption"] == "predict":
                    #self.send_text(msg['chat']['id'], "predict in progress")
                    time.sleep(3)
                    logger.info(f'Photo downloaded to: {photo_path}')
                    photo_S3_name = photo_path.split("/")
                    # Upload the photo to S3
                    client = boto3.client('s3')
                    client.upload_file(photo_path, images_bucket, photo_S3_name[1])

                

                    # TODO send a job to the SQS queue



                    my_photo_path = photo_path
                    chat_id = msg['chat']['id']

                    # Construct the message body
                    
                    message_body = {
                        'photo_path': photo_path,
                        'chat_id': chat_id}


                    response = sqs_client.send_message(QueueUrl=queue_name, MessageBody=str(message_body))
                    logger.info(f'response is : {response}')


                    self.send_text(msg['chat']['id'], "Your image is being processed. Please wait...")
                    return jsonify(status=200, job_id=response['MessageId'])



                else:
                    self.send_text(msg['chat']['id'], "error, Need to choose a valid caption")
            except Exception as e:
                logger.info(f"Error {e}")
                self.send_text(msg['chat']['id'], "failed - try again later")




        

        elif "text" in msg and msg["text"] == "hi":
            self.send_text(msg['chat']['id'],f"Hi: {msg['chat']['first_name']} {msg['chat']['last_name']}, how can I help you?")



        elif "text" in msg and msg["text"] != "hi":
            self.send_text(msg['chat']['id'], f'Your original message: {msg["text"]}')
        else:
            self.send_text(msg['chat']['id'], "failed - Please Provide Caption")
            # TODO upload the photo to S3
            # TODO send a job to the SQS queue
            # TODO send message to the Telegram end-user (e.g. Your image is being processed. Please wait...)
