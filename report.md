# Báo Cáo Lab GPU FinOps & Cost Optimization

## Thông tin sinh viên

- Họ tên: `Phạm Thành Duy`
- MSSV: `2A202600267`
- Môi trường chạy local: Windows + Docker Desktop + PowerShell
- Môi trường GPU: Kaggle Notebook với GPU T4
- Gateway tunnel: localhost.run

## 1. Mục tiêu bài lab

Bài lab này mô phỏng quy trình GPU FinOps cho một hệ thống AI có sử dụng GPU. Mục tiêu chính là hiểu cách theo dõi tài nguyên GPU, ghi nhận chi phí, so sánh on-demand và spot instance, đánh giá lãng phí tài nguyên, áp dụng autoscaling, và phân tích tối ưu chi phí khi chạy workload thực tế trên GPU.

Kiến trúc bài lab gồm hai phần:

- Local Docker Compose chạy các service mô phỏng: GPU Node Manager, Billing API, Spot Manager, Autoscaler, Cost Tracker và Gateway.
- Kaggle Notebook chạy workload GPU thật, sau đó gửi metrics và billing data về Gateway thông qua tunnel.

Trong quá trình thực hiện, local gateway được chạy ở `http://localhost:8010` do port `8000` trên máy đã được một container khác sử dụng.

## 2. Kết quả thực hiện

### 2.1. Mock GPU Cluster Monitoring

Ở phần đầu, notebook kết nối thành công tới Gateway và đọc được trạng thái cụm GPU mô phỏng. Cụm GPU ban đầu gồm nhiều node với các loại GPU khác nhau như T4, A100 và V100. Các metrics chính bao gồm tổng số GPU, số GPU đang bận, số GPU idle, mức sử dụng trung bình, bộ nhớ GPU đang dùng và power draw.

Kết quả quan sát cho thấy hệ thống có thể cung cấp góc nhìn tổng quan về năng lực GPU cluster, giúp phát hiện tình trạng idle GPU hoặc over-provisioning.

### 2.2. Workload Submission và Billing

Notebook đã gửi nhiều workload giả lập vào cluster, sau đó ghi nhận billing event tương ứng. Mỗi workload có các thông tin như loại GPU, số lượng GPU, thời lượng chạy và lựa chọn spot/on-demand.

Billing API tính toán chi phí dựa trên đơn giá GPU theo giờ. Kết quả cho thấy:

- Workload dùng A100 có chi phí cao hơn đáng kể so với T4.
- Spot instance giúp giảm chi phí so với on-demand.
- Cost tracking theo workload giúp phân bổ chi phí theo project hoặc theo loại GPU.

Theo dashboard local sau khi chạy lab, billing summary ghi nhận khoảng:

- Tổng chi phí default project: khoảng `$4.092`
- Tổng savings: khoảng `$4.2453`
- Tổng workloads: `27`
- Chi phí theo GPU chính: T4 và A100

Các con số này có thể thay đổi nếu notebook được chạy lại nhiều lần.

### 2.3. Spot Instance Management

Phần Spot Manager mô phỏng giá spot thấp hơn on-demand khoảng 70%. Notebook đã thực hiện:

- Kiểm tra spot pricing.
- Request spot instances.
- Mô phỏng preemption.
- Tính toán savings report.

Kết quả cho thấy spot instance là lựa chọn hiệu quả cho các workload có thể chịu được rủi ro bị gián đoạn, ví dụ batch job, training thử nghiệm hoặc workload có checkpoint. Tuy nhiên, với các workload production có yêu cầu deadline nghiêm ngặt, cần cân bằng giữa savings và preemption risk.

### 2.4. Autoscaling

Autoscaler được cấu hình theo policy dạng KEDA-like, dựa trên các ngưỡng utilization:

- Scale up khi GPU utilization cao.
- Scale down khi utilization thấp.
- Có cooldown để tránh scaling quá thường xuyên.
- Có giới hạn min/max nodes.

Khi trigger autoscaler evaluation nhiều lần, hệ thống đưa ra action tương ứng với trạng thái cluster. Đây là cơ chế quan trọng để giảm over-provisioning, vì GPU idle vẫn phát sinh chi phí ngay cả khi không chạy workload hữu ích.

### 2.5. Cost Analysis và Optimization

Cost Tracker tạo cost snapshots và phân tích lãng phí dựa trên idle GPU, utilization thấp và chi phí đang phát sinh. Dashboard sau khi chạy lab cho thấy:

- Tổng GPU mô phỏng: `18`
- GPU busy: `17`
- GPU idle: `1`
- Average utilization: khoảng `72.79%`
- Waste severity: `LOW`
- Potential monthly savings: khoảng `$632.06`

Các recommendation chính thường xoay quanh:

- Scale down GPU idle.
- Dùng spot instance cho workload phù hợp.
- Chọn GPU type phù hợp workload thay vì luôn dùng GPU mạnh nhất.
- Tối ưu batch size, mixed precision và thời gian chạy training.

### 2.6. Visualization

Notebook đã tạo các biểu đồ trực quan hóa chi phí và utilization, bao gồm:

- Cost breakdown theo loại GPU.
- Cost time-series.
- Waste percentage theo thời gian.
- Dashboard tổng hợp.

Các biểu đồ này giúp quan sát xu hướng chi phí và xác định phần nào gây lãng phí nhiều nhất. Đây là thành phần quan trọng trong FinOps vì dữ liệu chi phí cần được trình bày đủ rõ để hỗ trợ quyết định vận hành.

## 3. Real GPU Workload trên Kaggle

### 3.1. GPU Detection

Notebook được chạy trên Kaggle với GPU T4. Ban đầu thử với P100 gặp lỗi CUDA `no kernel image is available for execution on the device`, nhiều khả năng do phiên bản PyTorch/CUDA hiện tại không còn tương thích tốt với compute capability của P100. Sau khi chuyển sang T4, notebook chạy ổn định.

GPU T4 phù hợp cho bài lab vì hỗ trợ tốt mixed precision và Tensor Cores, giúp so sánh FP32 và AMP rõ hơn.

### 3.2. FP32 Training

Cell 22 chạy baseline training bằng FP32 trên mô hình ResNet-18 với dataset CIFAR-10.

Kết quả chính:

- Số epoch: `[Điền NUM_EPOCHS, thường là 3]`
- Tổng thời gian FP32: `[Điền từ Cell 22]`
- Accuracy cuối: `[Điền từ Cell 22]`
- Peak memory FP32: `[Điền từ Cell 22]`
- Chi phí FP32 ước tính: `[Điền từ Cell 25]`

FP32 là baseline dễ so sánh, nhưng thường tiêu tốn nhiều memory và thời gian hơn so với mixed precision.

### 3.3. Mixed Precision AMP Training

Cell 23 chạy cùng workload với AMP. AMP sử dụng mixed precision để giảm memory footprint và tăng throughput trên GPU có Tensor Cores như T4.

Kết quả chính:

- Tổng thời gian AMP: `[Điền từ Cell 23]`
- Accuracy cuối: `[Điền từ Cell 23]`
- Peak memory AMP: `[Điền từ Cell 23]`
- Chi phí AMP ước tính: `[Điền từ Cell 25]`
- Savings so với FP32: `[Điền từ Cell 24 hoặc Cell 25]`

Kết quả kỳ vọng là AMP có thời gian chạy ngắn hơn hoặc dùng ít memory hơn FP32. Nếu accuracy không giảm đáng kể, AMP là một chiến lược tối ưu chi phí tốt cho training.

### 3.4. So sánh FP32 và AMP

Từ Cell 24, so sánh FP32 và AMP theo các tiêu chí:

- Training time.
- Cost per run.
- Peak GPU memory.
- GPU utilization.
- Accuracy.

Nhận xét:

- Nếu AMP giảm thời gian training, chi phí GPU theo giờ cũng giảm.
- Nếu AMP giảm memory, có thể tăng batch size hoặc dùng GPU nhỏ hơn.
- Với T4, AMP thường có lợi thế rõ hơn so với P100 do T4 có Tensor Cores.

## 4. Advanced GPU Cost Optimization

### 4.1. Multi-GPU Cost Analysis

Cell 27 phân tích chi phí khi tăng số lượng GPU. Kết quả cho thấy tăng GPU không phải lúc nào cũng giảm chi phí, vì scaling efficiency thường không tuyến tính. Ví dụ, 2 GPU có thể không nhanh gấp đúng 2 lần, 4 GPU có thể có overhead communication lớn hơn.

Bài học chính: số GPU tối ưu là điểm cân bằng giữa thời gian hoàn thành và tổng chi phí, không đơn thuần là cấu hình mạnh nhất.

### 4.2. Project Cost Forecasting

Cell 28 mô phỏng forecast chi phí theo các phase của project. Forecast có xét uncertainty để tạo confidence interval. Cách làm này hữu ích trong thực tế vì workload AI thường có biến động lớn về thời gian training, số lần experiment và tài nguyên cần dùng.

### 4.3. Optimization Opportunity Analysis

Cell 29 xếp hạng các cơ hội tối ưu theo savings, effort, risk và dependencies. Một số chiến lược đáng chú ý:

- Sử dụng mixed precision.
- Dùng spot/preemptible instance cho workload phù hợp.
- Chuyển sang GPU type hiệu quả hơn.
- Autoscaling để giảm idle GPU.
- Theo dõi cost allocation theo project/team.

### 4.4. Integrated Cost Dashboard

Cell 30 tổng hợp nhiều góc nhìn vào một dashboard: cost curve, forecast, savings, roadmap và metrics hiệu quả. Dashboard này phù hợp để trình bày cho cả team kỹ thuật và stakeholder tài chính.

### 4.5. Challenge Strategy

Cell 31 yêu cầu thiết kế chiến lược tối ưu cho bài toán fine-tuning LLM với baseline 8x A100 trong 200 giờ.

Chiến lược đề xuất:

1. Tính baseline cost:
   - Baseline = 8 GPU x 200 giờ x đơn giá A100.
   - Với A100 on-demand `$3.67/h`, baseline cost khoảng `$5,872`.

2. Áp dụng mixed precision:
   - Chuyển từ FP32 sang AMP/BF16 nếu model và framework hỗ trợ.
   - Mục tiêu giảm thời gian training và memory usage.

3. Dùng spot instance có kiểm soát:
   - Dùng spot cho experiment, tuning, hoặc giai đoạn có checkpoint.
   - Không dùng spot cho phase cuối nếu deadline hoặc reliability là ưu tiên cao.

4. Tối ưu số lượng GPU:
   - Không mặc định dùng 8 GPU.
   - Chạy phân tích scaling efficiency để xác định cấu hình tối ưu như 4 GPU hoặc 6 GPU nếu tổng cost-performance tốt hơn.

5. Bật checkpointing và resume:
   - Giảm rủi ro mất tiến độ khi spot instance bị preempt.
   - Giúp workload chịu lỗi tốt hơn.

6. Theo dõi cost theo từng phase:
   - Data preparation, training, evaluation, hyperparameter tuning.
   - Cảnh báo khi vượt budget hoặc khi utilization thấp.

Kết luận cho scenario: để đưa chi phí xuống dưới budget `$5,000`, nên kết hợp mixed precision, lựa chọn GPU count tối ưu, spot instance có kiểm soát và checkpointing. Không nên chỉ scale bằng nhiều A100 on-demand vì chi phí tăng nhanh và có thể không đạt hiệu quả tuyến tính.

## 5. Bài học rút ra

Qua bài lab, em rút ra các bài học chính:

- GPU FinOps không chỉ là giảm chi phí, mà là tối ưu cost-performance.
- GPU idle vẫn phát sinh chi phí, nên monitoring và autoscaling rất quan trọng.
- Spot instance có thể tiết kiệm đáng kể nhưng cần quản trị rủi ro preemption.
- Mixed precision là một kỹ thuật tối ưu mạnh cho GPU hiện đại như T4.
- Multi-GPU scaling cần được đo đạc thực tế vì speedup không tuyến tính.
- Dashboard và cost allocation giúp team AI đưa quyết định dựa trên dữ liệu thay vì cảm tính.

## 6. Kết luận

Bài lab đã hoàn thành toàn bộ pipeline GPU FinOps từ local mock services đến real GPU workload trên Kaggle. Hệ thống đã mô phỏng được các khía cạnh quan trọng của vận hành GPU trong thực tế: monitoring, billing, spot pricing, autoscaling, waste analysis, visualization, real training và advanced cost planning.

Kết quả cho thấy các chiến lược như mixed precision, autoscaling, spot instance và lựa chọn GPU phù hợp có thể giúp giảm chi phí đáng kể mà vẫn duy trì hiệu quả training. Đây là nền tảng quan trọng khi triển khai các hệ thống AI production có sử dụng GPU ở quy mô lớn.
