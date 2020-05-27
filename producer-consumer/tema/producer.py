"""
This module represents the Producer.

Computer Systems Architecture Course
Assignment 1
March 2020
"""

from threading import Thread
from time import sleep

class Producer(Thread):
    """
    Class that represents a producer.
    """
    marketplace = None
    wait_time = 0.0
    list_of_products = []
    prod_id = 0

    def __init__(self, products, marketplace, republish_wait_time, **kwargs):
        """
        Constructor.

        @type products: List()
        @param products: a list of products that the producer will produce

        @type marketplace: Marketplace
        @param marketplace: a reference to the marketplace

        @type republish_wait_time: Time
        @param republish_wait_time: the number of seconds that a producer must
        wait until the marketplace becomes available

        @type kwargs:
        @param kwargs: other arguments that are passed to the Thread's __init__()

        The constructor starts the Thread and registers the Thread as a producer
        """
        Thread.__init__(self, **kwargs)
        self.marketplace = marketplace
        self.wait_time = republish_wait_time
        self.list_of_products = products
        self.prod_id = marketplace.register_producer()


    def run(self):
        """
        The thread function iterates infinitely through the provided list. For each product
        tries to publish it until all products of that type where published, sleeping accordingly
        """
        nr_crt = 0
        list_size = len(self.list_of_products)
        while True:
            order = self.list_of_products[nr_crt % list_size]
            product = order[0]
            quantity = order[1]
            time_to_produce = order[2]
            while quantity > 0:
                sleep(time_to_produce)
                while self.marketplace.publish(self.prod_id, product) is False:
                    sleep(self.wait_time)
                quantity = quantity - 1
            nr_crt = nr_crt + 1
