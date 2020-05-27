"""
This module represents the Consumer.

Computer Systems Architecture Course
Assignment 1
March 2020
"""

from threading import Thread, current_thread
from time import sleep


class Consumer(Thread):
    """
    Class that represents a consumer.
    """
    carts = []
    marketplace = None
    retry_wait_time = 0.0
    cart_id = -1

    def __init__(self, carts, marketplace, retry_wait_time, **kwargs):
        """
        Constructor.

        :type carts: List
        :param carts: a list of add and remove operations

        :type marketplace: Marketplace
        :param marketplace: a reference to the marketplace

        :type retry_wait_time: Time
        :param retry_wait_time: the number of seconds that a producer must wait
        until the Marketplace becomes available

        :type kwargs:
        :param kwargs: other arguments that are passed to the Thread's __init__()
        """
        Thread.__init__(self, **kwargs)
        self.carts = carts
        self.marketplace = marketplace
        self.cart_id = self.marketplace.new_cart()
        self.retry_wait_time = retry_wait_time

    def run(self):
        for order_list in self.carts:
            for operation in order_list:
                op_type = operation['type']
                product = operation['product']
                quantity = operation['quantity']
                if op_type == "add":
                    while quantity > 0:
                        if self.marketplace.add_to_cart(self.cart_id, product) is True:
                            quantity = quantity - 1
                        else:
                            sleep(self.retry_wait_time)
                else:
                    while quantity > 0:
                        self.marketplace.remove_from_cart(self.cart_id, product)
                        quantity = quantity - 1
            list_to_print = self.marketplace.place_order(self.cart_id)
            for element in list_to_print:
                print(current_thread().getName(), "bought", element, sep=' ', flush=True)
