"""
This module represents the Marketplace.

Computer Systems Architecture Course
Assignment 1
March 2020
"""

from threading import Lock

class Marketplace:
    """
        Marketplace Class that acts like a buffer for the MPMC problem
    """
    producers_products = {} # {producer_id : [products]}
    producers_locks = {} # {producer_id : lock}
    consumers_carts = {} # {cart_id : [(producer_id, product)]}
    producers_registering_lock = Lock()
    consumers_registering_lock = Lock()
    max_queue = 0
    producer_id_generator = -1
    cart_id_generator = -1

    def __init__(self, queue_size_per_producer):
        """
        Constructor

        :type queue_size_per_producer: Int
        :param queue_size_per_producer: the maximum size of a queue associated with each producer
        """
        self.max_queue = queue_size_per_producer

    def register_producer(self):
        """
        Returns an id for the producer that calls this, generating increasing numbers
        in a thread-safe manner.
        """
        self.producers_registering_lock.acquire()
        self.producer_id_generator = self.producer_id_generator + 1
        new_id = self.producer_id_generator
        self.producers_registering_lock.release()
        self.producers_products[new_id] = []
        self.producers_locks[new_id] = Lock()
        return new_id

    def publish(self, producer_id, product):
        """
        Adds the product provided by the producer to the marketplace in a thread-safe manner
        only if there is space for it

        :type producer_id: String
        :param producer_id: producer id

        :type product: Product
        :param product: the Product that will be published in the Marketplace

        :returns True or False. If the caller receives False, it should wait and then try again.
        """
        self.producers_locks[producer_id].acquire()
        if len(self.producers_products[producer_id]) >= self.max_queue:
            self.producers_locks[producer_id].release()
            return False
        self.producers_products[producer_id].append(product)
        self.producers_locks[producer_id].release()
        return True

    def new_cart(self):
        """
        Creates a new cart for the consumer, with an id in a thread-safe manner

        :returns an int representing the cart_id
        """
        self.consumers_registering_lock.acquire()
        self.cart_id_generator = self.cart_id_generator + 1
        new_id = self.cart_id_generator
        self.consumers_registering_lock.release()
        self.consumers_carts[new_id] = []
        return new_id

    def add_to_cart(self, cart_id, product):
        """
        Adds a product to the given cart. The function iterates through all producers
        and searches for the desired product and removes it when found, in a thread-safe manner

        :type cart_id: Int
        :param cart_id: id cart

        :type product: Product
        :param product: the product to add to cart

        :returns True or False. If the caller receives False, it should wait and then try again
        """
        for producer_id in self.producers_products:
            self.producers_locks[producer_id].acquire()
            try:
                obj = self.producers_products[producer_id].index(product)
            except ValueError:
                self.producers_locks[producer_id].release()
                continue
            to_add = self.producers_products[producer_id].pop(obj)
            self.producers_locks[producer_id].release()
            self.consumers_carts[cart_id].append((producer_id, to_add))
            return True
        return False

    def remove_from_cart(self, cart_id, product):
        """
        Removes a product from cart. The function searches in the cart and adds the product
        to the producers in a thread-safe manner.

        :type cart_id: Int
        :param cart_id: id cart

        :type product: Product
        :param product: the product to remove from cart
        """
        product_index = 0
        for cart_product in self.consumers_carts[cart_id]:
            if cart_product[1] == product:
                producer_id, to_add = self.consumers_carts[cart_id].pop(product_index)
                self.producers_locks[producer_id].acquire()
                self.producers_products[producer_id].append(to_add)
                self.producers_locks[producer_id].release()
                return
            product_index = product_index + 1



    def place_order(self, cart_id):
        """
        Return a list with all the products in the cart.

        :type cart_id: Int
        :param cart_id: id cart
        """
        cart_to_checkout = self.consumers_carts[cart_id]
        self.consumers_carts[cart_id] = []
        to_return = [list(product) for product in zip(*cart_to_checkout)]
        if to_return == []:
            return to_return
        return to_return[1]
