package com.example.paymentservice.service;

import com.example.paymentservice.entity.Payment;
import com.example.paymentservice.repository.PaymentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {

    private final PaymentRepository paymentRepository;

    public Payment createPayment(Payment payment) {
        payment.setStatus("pending");
        payment.setCreatedAt(System.currentTimeMillis());
        payment.setUpdatedAt(System.currentTimeMillis());
        
        Payment savedPayment = paymentRepository.save(payment);
        log.info("Payment created: {} for order: {}", savedPayment.getId(), savedPayment.getOrderId());
        
        return savedPayment;
    }

    public Optional<Payment> getPaymentById(Long id) {
        return paymentRepository.findById(id);
    }

    public Optional<Payment> getPaymentByOrderId(Long orderId) {
        return paymentRepository.findByOrderId(orderId);
    }

    public Optional<Payment> getPaymentByTransactionId(String transactionId) {
        return paymentRepository.findByTransactionId(transactionId);
    }

    public List<Payment> getPaymentsByStatus(String status) {
        return paymentRepository.findByStatus(status);
    }

    public List<Payment> getAllPayments() {
        return paymentRepository.findAll();
    }

    public Payment processPayment(Long paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new RuntimeException("Payment not found with id: " + paymentId));

        payment.setStatus("processing");
        payment.setUpdatedAt(System.currentTimeMillis());

        try {
            // Simulate payment processing
            if (validatePayment(payment)) {
                String transactionId = UUID.randomUUID().toString();
                payment.setTransactionId(transactionId);
                payment.setStatus("completed");
                log.info("Payment {} processed successfully. Transaction ID: {}", paymentId, transactionId);
            } else {
                payment.setStatus("failed");
                payment.setFailureReason("Payment validation failed");
                log.warn("Payment {} validation failed", paymentId);
            }
        } catch (Exception e) {
            payment.setStatus("failed");
            payment.setFailureReason(e.getMessage());
            log.error("Payment processing failed for payment {}", paymentId, e);
        }

        payment.setUpdatedAt(System.currentTimeMillis());
        return paymentRepository.save(payment);
    }

    public Payment refundPayment(Long paymentId) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new RuntimeException("Payment not found with id: " + paymentId));

        if (!"completed".equals(payment.getStatus())) {
            throw new RuntimeException("Only completed payments can be refunded");
        }

        payment.setStatus("refunded");
        payment.setUpdatedAt(System.currentTimeMillis());
        
        log.info("Payment {} refunded", paymentId);
        return paymentRepository.save(payment);
    }

    public Payment updatePayment(Long id, Payment paymentDetails) {
        return paymentRepository.findById(id)
                .map(payment -> {
                    payment.setAmount(paymentDetails.getAmount());
                    payment.setCurrency(paymentDetails.getCurrency());
                    payment.setPaymentMethod(paymentDetails.getPaymentMethod());
                    payment.setUpdatedAt(System.currentTimeMillis());
                    return paymentRepository.save(payment);
                })
                .orElseThrow(() -> new RuntimeException("Payment not found with id: " + id));
    }

    public void deletePayment(Long id) {
        paymentRepository.deleteById(id);
    }

    private boolean validatePayment(Payment payment) {
        // Basic validation logic
        return payment.getAmount() > 0 && 
               payment.getCurrency() != null && 
               !payment.getCurrency().isEmpty();
    }
}
