# แบบฝึกหัด Observability ขั้นสูง 🕵️‍♂️

แบบฝึกหัดเหล่านี้จำลองปัญหาจริงใน production ที่ต้องใช้ทักษะนักสืบกับ Azure Application Insights ทุก bug ถูกซ่อนอย่างแนบเนียนและจะโผล่มาเฉพาะเงื่อนไขพิเศษเท่านั้น!

## สิ่งที่ต้องเตรียม 📋

1. ทั้งสอง API ต้องรันอยู่ (local หรือบน Azure)
2. ตั้งค่า Azure Application Insights ให้เรียบร้อย
3. เปิดใช้งาน bug features ผ่าน environment variables

## การเปิดใช้งาน Bug ขั้นสูง 🐛

ตั้งค่า environment variables เหล่านี้ใน Downstream API เพื่อเปิด bug เฉพาะ:

```bash
# เปิด bug ทั้งหมดเพื่อความท้าทายสูงสุด!
export ADVANCED_BUG_HARDCODED_ID=true
export ADVANCED_BUG_ORDER_RANGE=true
export ADVANCED_BUG_MEMORY_LEAK=true
export ADVANCED_BUG_THREAD_POOL=true
export ADVANCED_BUG_CACHE_POISON=true
export ADVANCED_BUG_CPU_SPIKE=true

# หรือใส่ใน appsettings.json
{
  "ADVANCED_BUG_HARDCODED_ID": true,
  "ADVANCED_BUG_ORDER_RANGE": true,
  "ADVANCED_BUG_MEMORY_LEAK": true,
  "ADVANCED_BUG_THREAD_POOL": true,
  "ADVANCED_BUG_CACHE_POISON": true,
  "ADVANCED_BUG_CPU_SPIKE": true
}
```

## วิธีรัน Bug Hunter 🏃‍♂️

ใช้ test data generator ภาษา C# แบบ cross-platform เพื่อกระตุ้น bug:

```bash
# Build test data generator
cd test-data-generator
dotnet build

# รันทุกการทดสอบ
dotnet run -- http://localhost:5000 all

# รันเฉพาะประเภทการทดสอบ
dotnet run -- http://localhost:5000 random   # ทดสอบ product ID แบบสุ่ม
dotnet run -- http://localhost:5000 range    # ทดสอบช่วง order
dotnet run -- http://localhost:5000 prime    # ทดสอบเลขจำนวนเฉพาะ
dotnet run -- http://localhost:5000 load     # ทดสอบ load patterns
dotnet run -- http://localhost:5000 palindrome # ทดสอบ palindrome IDs
dotnet run -- http://localhost:5000 edge     # ทดสอบ edge cases
```

![Test Data Generator Console](../documents/console_app_generate_advance_exercise_test_data.png)
*Console application สำหรับสร้าง test data เพื่อกระตุ้น bug ต่างๆ ในแบบฝึกหัดขั้นสูง*

---

## แบบฝึกหัด 1: ปริศนาสินค้าช้าลึกลับ 🐌

### สถานการณ์
**รายงานจากลูกค้า:** "บางหน้าสินค้าโหลดเร็วมาก แต่บางอันช้าสุดๆ (3+ วินาที) ดูเหมือนจะสุ่ม แต่สม่ำเสมอ - สินค้าตัวเดิมช้าตลอดเลย"

### ภารกิจของคุณ
หาว่า product ID ไหนมีปัญหา performance และหา pattern ให้เจอ

### สิ่งที่จะเห็นใน Logs
- "Applying enhanced validation for product {ProductId}"
- "Legacy system validation initiated"
- "Legacy validation completed"

Log ดูปกติมาก - ระบบเก่าๆ มักจะช้าอยู่แล้ว แต่ทำไมถึงช้าเฉพาะบางสินค้า?

### วิธีสร้างการทดสอบ
```bash
# รันการทดสอบ random product ID
cd test-data-generator
dotnet run -- http://localhost:5000 random
```

### ขั้นตอนการสืบสวน
1. รัน test script แล้วสังเกตว่า ID ไหนช้า
2. ใช้ Application Insights query หา request ที่ช้า:
   ```kql
   requests
   | where name contains "products"
   | where duration > 2000
   | project productId = tostring(customDimensions.ProductId), duration
   | summarize count() by productId
   ```
3. หา pattern ใน ID ที่ช้า

### คำใบ้ (เปิดดูทีละอัน)
<details>
<summary>คำใบ้ 1</summary>
ดูที่ตัวเลข ID ที่ช้า มีอะไรที่เหมือนกันไหม?
</details>

<details>
<summary>คำใบ้ 2</summary>
ลองคิดถึงความหมายทางวัฒนธรรมหรือความเชื่อเรื่องตัวเลขบางตัว...
</details>

<details>
<summary>เฉลย</summary>
Bug คือ: สินค้าที่มี ID "ไม่เป็นมงคล" (13, 42, 99, 666, 1337, 2024, 9999) จะมี delay 3 วินาทีที่ hardcode ไว้ เลียนแบบ legacy code ที่มี developer เชื่อเรื่องโชคลางหรือมีการจัดการพิเศษสำหรับ demo/test IDs
</details>

---

## แบบฝึกหัด 2: ความผิดปกติการประมวลผลคำสั่งซื้อ 📊

### สถานการณ์
**รายงานจากลูกค้า:** "เราเห็นจำนวนคำสั่งซื้อที่ล้มเหลวเพิ่มขึ้นมาก แต่เฉพาะเลขคำสั่งซื้อบางช่วง ฝ่ายบริการลูกค้าล้นมือกับการร้องเรียนเรื่องคำสั่งซื้อในช่วง 1000"

### ภารกิจของคุณ
ระบุว่าช่วง order ID ไหนที่ล้มเหลวและหา pattern ความล้มเหลว

### สิ่งที่จะเห็นใน Logs
- "Order validation failed for {OrderId}: Database constraint violation"
- "Order {OrderId} failed validation check against table ORDER_CONSTRAINTS"
- Exception: "Foreign key constraint FK_ORDER_VALIDATION failed"

ดูเหมือนปัญหา database แต่ทำไมเฉพาะช่วง order บางช่วง?

### วิธีสร้างการทดสอบ
```bash
# รันการทดสอบช่วง order
cd test-data-generator
dotnet run -- http://localhost:5000 range
```

### ขั้นตอนการสืบสวน
1. รัน test script เพื่อสร้าง order จาก 900-1200
2. Query Application Insights หาความล้มเหลว:
   ```kql
   exceptions
   | where message contains "BR-1099"
   | extend orderId = toint(customDimensions.OrderId)
   | summarize failureCount = count() by bin(orderId, 10)
   | order by orderId
   ```
3. คำนวณอัตราความล้มเหลวตามช่วง

### คำใบ้ (เปิดดูทีละอัน)
<details>
<summary>คำใบ้ 1</summary>
โฟกัสที่ order ระหว่าง 1000-1099 อัตราความล้มเหลวในช่วงนี้เท่าไหร่?
</details>

<details>
<summary>คำใบ้ 2</summary>
Error message พูดถึง "BR-1099" - อาจเป็น business rule ที่เกี่ยวกับช่วง ID นี้
</details>

<details>
<summary>เฉลย</summary>
Bug คือ: Order ที่มี ID 1000-1099 จะล้มเหลว 90% เพราะ "business rule BR-1099" เลียนแบบ database constraint หรือ business logic ที่ถือว่าช่วงนี้เป็นช่วงสงวน/พิเศษ
</details>

---

## แบบฝึกหัด 3: ปริศนา Memory Leak 💾

### สถานการณ์
**รายงานจากลูกค้า:** "Memory ของ API server เพิ่มขึ้นเรื่อยๆ ตลอดทั้งวัน ต้อง restart ทุกคืน Memory leak ดูเหมือนจะเกี่ยวกับการดูสินค้าบางตัว"

### ภารกิจของคุณ
หาว่า product ID ไหนทำให้เกิด memory leak

### สิ่งที่จะเห็นใน Logs
- "Initializing product cache for {ProductId}"
- "Product {ProductId} cached for performance optimization"

การทำ cache ปกติใช่ไหม? แต่ทำไม memory ไม่ถูกคืน?

### วิธีสร้างการทดสอบ
```bash
# รันการทดสอบเลขจำนวนเฉพาะ
cd test-data-generator
dotnet run -- http://localhost:5000 prime
```

### ขั้นตอนการสืบสวน
1. Monitor memory metrics ขณะรันการทดสอบ
2. Query หา patterns:
   ```kql
   customMetrics
   | where name contains "Memory"
   | summarize avg(value) by bin(timestamp, 1m)
   | render timechart
   ```
3. เชื่อมโยง memory spikes กับ product ID เฉพาะ

### คำใบ้ (เปิดดูทีละอัน)
<details>
<summary>คำใบ้ 1</summary>
ทดสอบทั้ง prime และ non-prime product IDs เปรียบเทียบ performance
</details>

<details>
<summary>คำใบ้ 2</summary>
เลขจำนวนเฉพาะพิเศษในวิชาคณิตศาสตร์ บางทีอาจพิเศษใน code ด้วย?
</details>

<details>
<summary>เฉลย</summary>
Bug คือ: สินค้าที่มี ID เป็นจำนวนเฉพาะจะ leak memory 5MB ต่อ prime ID ที่ไม่ซ้ำ Memory ไม่เคยถูกคืน เลียนแบบ cache ที่ไม่ลบ entry ของจำนวนเฉพาะ
</details>

---

## แบบฝึกหัด 4: ปัญหา Performance เป็นรอบ ⏰

### สถานการณ์
**รายงานจากลูกค้า:** "ทุกๆ สองสาม request ระบบจะค้างไป 5 วินาที มันทำลาย user experience ช่วง peak hours"

### ภารกิจของคุณ
ระบุ pattern ที่ทำให้เกิดความช้าเป็นรอบ

### สิ่งที่จะเห็นใน Logs
- "Starting scheduled maintenance task"
- "Synchronous database cleanup initiated for request {RequestNumber}"
- "Maintenance task completed"

Maintenance เป็นเรื่องปกติ แต่ทำไมรันช่วง peak hours และ block requests?

### วิธีสร้างการทดสอบ
```bash
# รันการทดสอบ load pattern
cd test-data-generator
dotnet run -- http://localhost:5000 load
```

### ขั้นตอนการสืบสวน
1. ส่ง request เร็วๆ 50 อันแล้วสังเกต pattern
2. Query หา slow requests:
   ```kql
   requests
   | where duration > 3000
   | extend requestNumber = toint(customDimensions.RequestNumber)
   | project requestNumber, duration
   | order by requestNumber
   ```
3. หา pattern ทางคณิตศาสตร์ใน request numbers

### คำใบ้ (เปิดดูทีละอัน)
<details>
<summary>คำใบ้ 1</summary>
นับเลข request ที่ช้า มี pattern แบบทุกๆ N request ไหม?
</details>

<details>
<summary>คำใบ้ 2</summary>
เช็คว่าตำแหน่ง request ที่ช้าหารด้วยเลขเฉพาะลงตัวไหม
</details>

<details>
<summary>เฉลย</summary>
Bug คือ: ทุก request ที่ 10 จะ block thread 5 วินาที เลียนแบบ thread pool exhaustion ปัญหาใน production ทั่วไปที่ batch processing เป็นระยะรบกวน request handling
</details>

---

## แบบฝึกหัด 5: หายนะ Cache เสียหาย 🔥

### สถานการณ์
**รายงานจากลูกค้า:** "บางครั้งสินค้าทั้งหมดแสดงเป็น 'CORRUPTED_DATA' ราคา -1 มันหายเองหลัง 30 วินาที แต่ลูกค้าตื่นตระหนกมาก!"

### ภารกิจของคุณ
หาว่าอะไรทำให้ cache เสียหาย

### สิ่งที่จะเห็นใน Logs
- "Cache miss for product {ProductId}, loading from database"
- "Unexpected data format for product {ProductId}, using fallback values"

ดูเหมือนปัญหา data format แต่ทำไมกระทบ request หลังจากนั้นทั้งหมด?

### วิธีสร้างการทดสอบ
```bash
# รันการทดสอบ edge case
cd test-data-generator
dotnet run -- http://localhost:5000 edge
```

### ขั้นตอนการสืบสวน
1. ทดสอบ edge cases (0, ติดลบ, ID ใหญ่มาก)
2. Monitor request ปกติหลังจากนั้น
3. Query หา corrupted responses:
   ```kql
   requests
   | where responseCode == 200
   | extend responseBody = tostring(customDimensions.ResponseBody)
   | where responseBody contains "CORRUPTED_DATA"
   | project timestamp, productId = customDimensions.ProductId
   ```

### คำใบ้ (เปิดดูทีละอัน)
<details>
<summary>คำใบ้ 1</summary>
จะเกิดอะไรขึ้นเมื่อ request product ID 0 หรือ ID ติดลบ?
</details>

<details>
<summary>คำใบ้ 2</summary>
หลังจาก request ID ที่ผิด ลอง request สินค้าปกติทันที เห็นอะไรไหม?
</details>

<details>
<summary>เฉลย</summary>
Bug คือ: Product ID ≤ 0 จะทำให้ cache เสียหาย 30 วินาที ทำให้ request หลังจากนั้นทั้งหมดได้ข้อมูลเสียหาย เลียนแบบช่องโหว่ cache poisoning ที่ input ผิดทำให้ shared state เสียหาย
</details>

---

## แบบฝึกหัด 6: อาการ CPU พุ่งสูง 🔥

### สถานการณ์
**รายงานจากลูกค้า:** "Monitoring เราแสดง CPU spikes รุนแรงที่ทำให้ server เต็ม 100% หลายวินาที มันเกิดกับสินค้าบางตัวแต่เราหา pattern ไม่เจอ Server ไม่ตอบสนองเลยช่วง spike"

### ภารกิจของคุณ
ระบุว่า product ID ไหนทำให้ CPU ใช้งานสูงมากและหา pattern

### สิ่งที่จะเห็นใน Logs
- "Calculating recommendations for product {ProductId}"
- "Running similarity analysis for product {ProductId}"
- "Recommendation calculation completed in {ElapsedMs}ms"

Recommendation engine ใช้ CPU เยอะเป็นปกติ แต่ทำไมบางสินค้าใช้เวลานาน 10-100 เท่า?

### วิธีสร้างการทดสอบ
```bash
# รันการทดสอบ palindrome
cd test-data-generator
dotnet run -- http://localhost:5000 palindrome

# หรือทดสอบ palindrome ID เฉพาะ
curl http://localhost:5001/products/121
curl http://localhost:5001/products/1221
curl http://localhost:5001/products/12321
```

### ขั้นตอนการสืบสวน
1. Monitor CPU metrics ขณะทดสอบ product ID ต่างๆ
2. Query Application Insights หา request ที่นาน:
   ```kql
   requests
   | where name contains "products"
   | where duration > 5000
   | extend productId = tostring(customDimensions.ProductId)
   | project productId, duration
   | order by duration desc
   ```
3. หา pattern ใน product ID ที่ทำให้เกิด spike
4. เช็ค performance counters ช่วง spike:
   ```kql
   performanceCounters
   | where name == "% Processor Time"
   | where value > 80
   | summarize max(value) by bin(timestamp, 10s)
   | render timechart
   ```

### คำใบ้ (เปิดดูทีละอัน)
<details>
<summary>คำใบ้ 1</summary>
ทดสอบ product ID ที่อ่านจากหน้าไปหลังได้เหมือนกัน (เช่น 121, 1001, 12321)
</details>

<details>
<summary>คำใบ้ 2</summary>
คิดถึงคุณสมบัติทางคณิตศาสตร์หรือภาษาศาสตร์ของตัวเลข เราเรียกเลขที่กลับหน้าหลังแล้วเหมือนเดิมว่าอะไร?
</details>

<details>
<summary>เฉลย</summary>
Bug คือ: สินค้าที่มี palindrome ID (เลขที่อ่านจากหน้าไปหลังเหมือนกัน เช่น 121, 131, 1221, 12321) จะทำให้เกิดการคำนวณหนักที่ทำ mathematical operations 50 ล้านครั้ง เลียนแบบ algorithm ที่ไม่ efficient หรือคำนวณที่ไม่จำเป็นสำหรับ special cases

Palindrome ID ทั่วไปที่ควรทดสอบ:
- หลักเดียว: 1-9
- สองหลัก: 11, 22, 33, 44, 55, 66, 77, 88, 99
- สามหลัก: 101, 111, 121, 131, 141, 151, 161, 171, 181, 191, 202, 212, ฯลฯ
- สี่หลัก: 1001, 1111, 1221, 1331, 1441, 1551, 1661, 1771, 1881, 1991, 2002, ฯลฯ
</details>

---

## 📸 ตัวอย่างผลลัพธ์ใน Azure Application Insights

### การตรวจจับ Performance Issues
![Slow Transactions in Azure](../documents/result_slow_transection_in_azure.png)
*ตัวอย่างการแสดง slow transactions ใน Application Insights - สังเกต response time ที่สูงผิดปกติ*

![Multiple Slow Transactions](../documents/result_many_slow_transection_in_azure.png)
*การแสดง pattern ของ slow transactions หลายรายการ - ช่วยในการวิเคราะห์หา root cause*

### การตรวจจับ Failures
![Failed Transactions](../documents/result_fail_transection_in_azure_by_calling_api.png)
*Dashboard แสดง failed transactions จากการเรียก API - สังเกต error rate และ status codes*

### การ Monitor Resource Usage
![CPU Spike Detection](../documents/result_cpu_peak_in_azure.png)
*กราฟแสดง CPU spike ใน Azure Monitor - ช่วยระบุช่วงเวลาที่มีปัญหา performance*

![Live CPU and Memory Monitoring](../documents/result_cpu_ram_peak_in_azure_live_monitor.png)
*Live monitoring dashboard แสดง CPU และ Memory usage แบบ real-time*

---

## 🔍 การล่า Bug แบบ Production จริง

### ความท้าทายแบบสมจริง

**ไม่มีสัญญาณ bug ที่ชัดเจน** - เหมือน production จริงๆ! คุณจะไม่เจอ:
- ไม่มีข้อความ "BUG DETECTED"
- ไม่มี event "BugTriggered"  
- ไม่มีการบอกตำแหน่ง code
- ไม่มี label ประเภท bug

### สิ่งที่คุณจะเจอ

เหมือนใน production คุณจะเห็น:
- Business logic logs ปกติ ("Applying enhanced validation", "Starting maintenance task")
- Performance metrics (latency, CPU, memory)
- Error patterns และ exceptions
- Request correlations

### วิธีล่า Bug แบบมืออาชีพ

1. **สร้าง Traffic**: ใช้ test data generator สร้าง load
2. **สังเกต Patterns**: หา anomalies ใน Application Insights
3. **เชื่อมโยงอาการ**: จับคู่ปัญหา performance กับ request patterns
4. **ตั้งสมมติฐาน**: ใช้ข้อมูลคาดเดาว่าเกิดอะไรขึ้น
5. **ยืนยันทฤษฎี**: ทดสอบ scenario เฉพาะเพื่อยืนยัน

### งานสืบสวนที่ต้องทำ

| อาการ | ต้องมองหา | วิธีสืบสวน |
|-------|-----------|-----------|
| Request ช้า | Duration > 2000ms | จัดกลุ่มตาม ProductId หา patterns |
| Failure rate สูง | Status 500/503 | วิเคราะห์ตามช่วง OrderId |
| Memory โต | Memory metrics เพิ่มขึ้น | เชื่อมโยงกับ ProductIds เฉพาะ |
| CPU spikes | CPU > 80% | จับคู่กับ request timings |
| Data เสียหาย | Response values ผิดปกติ | ติดตามว่าเริ่มเสียหายเมื่อไหร่ |

---

## KQL Queries สำหรับการสืบสวนแบบสมจริง

### หาสินค้าที่ช้า (ไม่มี Bug Labels!)
```kql
requests
| where name contains "products"
| where duration > 2000
| extend ProductId = tostring(customDimensions.ProductId)
| summarize 
    AvgDuration = avg(duration),
    Count = count(),
    P95Duration = percentile(duration, 95)
    by ProductId
| where Count > 2
| order by AvgDuration desc
// ดู pattern ใน ProductIds ที่ช้า - มีอะไรเหมือนกันไหม?
```

### วิเคราะห์ Order Failures ตามช่วง
```kql
exceptions
| where message contains "constraint" or message contains "validation"
| extend OrderId = toint(customDimensions.OrderId)
| summarize 
    FailureCount = count(),
    FailureRate = count() * 100.0 / 301.0
    by OrderRange = bin(OrderId, 100)
| order by OrderRange
// ช่วง order ไหนมี failure rate สูงผิดปกติ?
```

### ตรวจจับ Pattern การเติบโตของ Memory
```kql
performanceCounters
| where name == "Private Bytes"
| summarize MemoryMB = avg(value/1048576) by bin(timestamp, 1m)
| join kind=inner (
    requests
    | where name contains "products"
    | extend ProductId = toint(customDimensions.ProductId)
    | summarize RequestCount = count() by bin(timestamp, 1m), ProductId
) on timestamp
| order by timestamp
// Memory growth สัมพันธ์กับ ProductIds เฉพาะไหม?
```

### หา Request Patterns ในช่วงช้า
```kql
requests
| where duration > 3000
| serialize
| extend RequestNumber = row_number()
| extend PatternCheck = RequestNumber % 10
| summarize 
    SlowCount = count(),
    AvgDuration = avg(duration)
    by PatternCheck
| order by PatternCheck
// มี pattern ว่า request ไหนช้าไหม?
```

---

## KQL Queries สำหรับการสืบสวน

### หา Patterns ใน Slow Requests
```kql
requests
| where timestamp > ago(1h)
| where duration > 2000
| extend productId = toint(customDimensions.ProductId)
| summarize 
    avgDuration = avg(duration),
    maxDuration = max(duration),
    count = count()
    by productId
| where count > 2
| order by avgDuration desc
```

### ระบุกลุ่มความล้มเหลว
```kql
exceptions
| where timestamp > ago(1h)
| extend orderId = toint(customDimensions.OrderId)
| summarize failures = count() by bin(orderId, 100)
| render columnchart
```

### ติดตามการเติบโตของ Memory
```kql
performanceCounters
| where name == "Private Bytes"
| where timestamp > ago(1h)
| summarize memoryMB = avg(value/1048576) by bin(timestamp, 1m)
| render timechart
```

### ตรวจจับปัญหา Thread Pool
```kql
requests
| where timestamp > ago(30m)
| serialize 
| extend requestNumber = row_number()
| where duration > 3000
| project requestNumber, duration
| extend isDivisibleBy10 = (requestNumber % 10 == 0)
| summarize slowCount = count() by isDivisibleBy10
```

---

## เกณฑ์ความสำเร็จ ✅

สำหรับแต่ละแบบฝึกหัด คุณจะสำเร็จเมื่อสามารถ:
1. ✅ ระบุเงื่อนไขที่ทำให้เกิด bug ได้แม่นยำ
2. ✅ แสดงหลักฐานจาก Application Insights
3. ✅ อธิบายว่าทำไม pattern นี้ถึงทำให้เกิดปัญหาใน production
4. ✅ เสนอวิธีแก้ไขหรือ mitigation strategy

## สิ่งที่จะได้เรียนรู้ 🎓

หลังจากทำแบบฝึกหัดเหล่านี้เสร็จ คุณจะเข้าใจ:
- วิธีระบุ patterns ในข้อมูล telemetry
- Bug patterns ทั่วไปใน production
- ความสำคัญของ comprehensive monitoring
- Edge cases ส่งผลต่อ system stability อย่างไร
- ทำไม load testing ด้วย input ที่หลากหลายถึงสำคัญ

## ขั้นตอนต่อไป 🚀

1. ลองเปิด bug combinations ต่างๆ
2. สร้าง custom KQL queries เพื่อตรวจจับปัญหาเหล่านี้อัตโนมัติ
3. ตั้ง Azure Monitor alerts สำหรับ patterns เหล่านี้
4. ฝึกอธิบายสิ่งที่พบให้คนที่ไม่ใช่ technical เข้าใจ
5. ออกแบบ hidden bugs ของคุณเองสำหรับฝึกทีม

จำไว้ว่า: ใน production bug พวกนี้จะหายากกว่านี้มากถ้าไม่มี observability tools ที่ดี! 🕵️‍♂️