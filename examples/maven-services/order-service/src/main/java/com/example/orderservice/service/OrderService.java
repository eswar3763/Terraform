package com.example.orderservice.service;

import com.example.orderservice.entity.Order;
import com.example.orderservice.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final OrderRepository orderRepository;
    private final WebClient.Builder webClientBuilder;

    @Value("${USER_SERVICE_URL:http://user-service:8081}")
    private String userServiceUrl;

    @Value("${PAYMENT_SERVICE_URL:http://payment-service:8083}")
    private String paymentServiceUrl;

    public Order createOrder(Order order) {
        // Verify user exists
        if (!userExists(order.getUserId())) {
            throw new RuntimeException("User not found with id: " + order.getUserId());
        }

        order.setStatus("pending");
        order.setCreatedAt(System.currentTimeMillis());
        order.setUpdatedAt(System.currentTimeMillis());
        
        Order savedOrder = orderRepository.save(order);
        log.info("Order created: {}", savedOrder.getId());
        
        return savedOrder;
    }

    public Optional<Order> getOrderById(Long id) {
        return orderRepository.findById(id);
    }

    public List<Order> getOrdersByUserId(Long userId) {
        return orderRepository.findByUserId(userId);
    }

    public List<Order> getOrdersByStatus(String status) {
        return orderRepository.findByStatus(status);
    }

    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }

    public Order updateOrder(Long id, Order orderDetails) {
        return orderRepository.findById(id)
                .map(order -> {
                    order.setAmount(orderDetails.getAmount());
                    order.setCurrency(orderDetails.getCurrency());
                    order.setStatus(orderDetails.getStatus());
                    order.setDescription(orderDetails.getDescription());
                    order.setUpdatedAt(System.currentTimeMillis());
                    return orderRepository.save(order);
                })
                .orElseThrow(() -> new RuntimeException("Order not found with id: " + id));
    }

    public void deleteOrder(Long id) {
        orderRepository.deleteById(id);
    }

    public Order processOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found with id: " + orderId));

        order.setStatus("processing");
        order.setUpdatedAt(System.currentTimeMillis());
        
        try {
            // Call payment service
            Map<String, Object> paymentRequest = new HashMap<>();
            paymentRequest.put("orderId", orderId);
            paymentRequest.put("amount", order.getAmount());
            paymentRequest.put("currency", order.getCurrency());

            webClientBuilder.build()
                    .post()
                    .uri(paymentServiceUrl + "/api/payments/process")
                    .bodyValue(paymentRequest)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            order.setStatus("completed");
            log.info("Order {} processed successfully", orderId);
        } catch (Exception e) {
            order.setStatus("failed");
            log.error("Payment processing failed for order {}", orderId, e);
        }

        order.setUpdatedAt(System.currentTimeMillis());
        return orderRepository.save(order);
    }

    private boolean userExists(Long userId) {
        try {
            webClientBuilder.build()
                    .get()
                    .uri(userServiceUrl + "/api/users/" + userId + "/exists")
                    .retrieve()
                    .bodyToMono(Boolean.class)
                    .block();
            return true;
        } catch (Exception e) {
            log.warn("User service check failed for userId: {}", userId, e);
            return false;
        }
    }
}
