// Azure Function App - Queue Trigger Example
// File: src/functions/processOrder.ts
// This function processes orders from the Azure Storage Queue

import { app, InvocationContext } from "@azure/functions";
import mysql from "mysql2/promise";

export async function processOrder(
  queueItem: any,
  context: InvocationContext
): Promise<void> {
  context.log("Processing order from queue:", queueItem);

  try {
    // Parse queue message
    const order = typeof queueItem === "string" ? JSON.parse(queueItem) : queueItem;

    // Create connection pool
    const connection = await mysql.createConnection({
      host: process.env.MYSQL_HOST,
      database: process.env.MYSQL_DATABASE,
      user: process.env.MYSQL_USER,
      password: process.env.MYSQL_PASSWORD,
      port: 3306,
      enableKeepAlive: true,
      authPlugins: {
        mysql_native_password: () => () => process.env.MYSQL_PASSWORD,
      },
    });

    try {
      // Validate order
      if (!order.orderId || !order.userId) {
        throw new Error("Invalid order: missing orderId or userId");
      }

      context.log(`Processing order ${order.orderId} for user ${order.userId}`);

      // Update order status in database
      const updateQuery =
        "UPDATE orders SET status = ?, processed_at = NOW() WHERE id = ?";
      await connection.execute(updateQuery, ["processing", order.orderId]);

      // Call payment service (internal API call)
      const paymentResponse = await fetch("http://payment-service:8083/api/payments", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": process.env.API_KEY,
        },
        body: JSON.stringify({
          orderId: order.orderId,
          amount: order.amount,
          currency: order.currency || "USD",
        }),
      });

      if (!paymentResponse.ok) {
        throw new Error(`Payment service error: ${paymentResponse.statusText}`);
      }

      const paymentResult = await paymentResponse.json();
      context.log("Payment processed:", paymentResult);

      // Update order status to completed
      const completeQuery =
        "UPDATE orders SET status = ?, payment_id = ?, completed_at = NOW() WHERE id = ?";
      await connection.execute(completeQuery, ["completed", paymentResult.transactionId, order.orderId]);

      context.log(`Order ${order.orderId} completed successfully`);
    } finally {
      await connection.end();
    }
  } catch (error) {
    context.error("Error processing order:", error);
    // Re-throw to mark function execution as failed
    throw error;
  }
}

app.storageQueue("processOrder", {
  handler: processOrder,
});
