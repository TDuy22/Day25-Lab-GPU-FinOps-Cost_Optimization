# Báo Cáo Lab GPU FinOps & Cost Optimization

## Thông tin sinh viên

- Họ tên: Phạm Thành Duy
- MSSV: 2A202600267
- Môi trường local: Windows + Docker Desktop + PowerShell
- Môi trường GPU: Kaggle Notebook với GPU Tesla T4
- Cách kết nối Kaggle về local gateway: tunnel qua localhost.run
- Gateway local: `http://localhost:8010`

## 1. Mục tiêu bài lab

Bài lab mô phỏng một quy trình GPU FinOps cho hệ thống AI có sử dụng GPU. Mục tiêu là theo dõi tài nguyên GPU, ghi nhận chi phí, phân tích lãng phí, thử nghiệm spot instance, cấu hình autoscaling và đánh giá hiệu quả chi phí khi chạy workload thực tế trên GPU.

Kiến trúc bài lab gồm hai phần:

- Local Docker Compose chạy các service mô phỏng: GPU Node Manager, Billing API, Spot Manager, Autoscaler, Cost Tracker và Gateway.
- Kaggle Notebook chạy workload GPU thật, sau đó gửi metrics và billing data về Gateway thông qua tunnel.

Trong quá trình thực hiện trên Windows, port `8000` đã được một container khác sử dụng nên gateway của lab được publish qua port `8010`. Điều này không ảnh hưởng logic lab vì các service nội bộ vẫn giao tiếp với nhau qua Docker network.

## 2. Kết quả thực hiện các phần FinOps mô phỏng

### 2.1. GPU Cluster Monitoring

Notebook kết nối thành công tới Gateway và đọc được trạng thái GPU cluster mô phỏng. Tại Cell 3, cluster có 7 node với nhiều loại GPU gồm T4, A100 và V100. Một số node đang bận với utilization cao, trong khi một số GPU vẫn idle.

Metrics tổng hợp tại Cell 4:

| Chỉ số | Giá trị |
|---|---:|
| Total GPUs | 14 |
| Busy GPUs | 9 |
| Idle GPUs | 5 |
| Average utilization | 49.9% |
| Memory used | 223.8 GB |
| Memory capacity | 384.0 GB |
| Total power draw | 1133 W |
| Node count | 7 |

Nhận xét: cluster có đủ tài nguyên nhưng vẫn còn 5 GPU idle. Đây là dấu hiệu cần theo dõi trong FinOps vì GPU idle vẫn phát sinh chi phí nếu hạ tầng được provision sẵn.

### 2.2. Workload Submission và Billing

Notebook đã submit các workload mô phỏng như ResNet training, BERT training, inference API và LLM training. Sau khi submit, cluster đạt trạng thái:

- Busy GPUs: 14/14
- Utilization: 76.3%

Billing được ghi nhận theo workload:

| Workload | Loại | Cost | Savings |
|---|---|---:|---:|
| train-resnet-001 | On-demand | $0.0292 | $0.0000 |
| train-bert-002 | On-demand | $0.6117 | $0.0000 |
| inference-api-003 | Spot | $0.0035 | $0.0082 |
| train-llm-004 | Spot | $0.5505 | $1.2845 |

Billing summary tại Cell 6:

- Total cost: $3.9229
- Total savings: $4.1229
- Budget used: 3.9%
- Alert status: OK

Nhận xét: workload dùng A100 có chi phí cao hơn rõ rệt so với T4. Spot instance giúp giảm chi phí đáng kể, đặc biệt với workload dài hoặc workload có thể chịu được gián đoạn.

### 2.3. Spot Instance Management

Cell 7 hiển thị spot pricing hiện tại:

| GPU Type | On-demand | Spot price | Discount | Availability |
|---|---:|---:|---:|---|
| T4 | $0.35 | $0.2391 | 31.7% | low |
| A100 | $3.67 | $2.4253 | 33.9% | low |
| V100 | $2.48 | $1.5995 | 35.5% | medium |

Cell 8 request thành công ba spot instances:

- `spot-t4-001`: granted
- `spot-t4-002`: granted
- `spot-a100-001`: granted

Cell 9 mô phỏng preemption:

- Preempted instances: 1
- Still active: 5
- Spot cost: $0.0941
- On-demand equivalent: $0.3136
- Total saved: $0.2195, tương đương 70.0%

Nhận xét: spot instance phù hợp với batch jobs, training thử nghiệm hoặc các workload có checkpoint/resume. Với workload production hoặc deadline chặt, cần quản trị rủi ro preemption.

### 2.4. Autoscaling

Cell 10 cấu hình autoscaling policy:

| Tham số | Giá trị |
|---|---:|
| scale_up_threshold | 70.0 |
| scale_down_threshold | 25.0 |
| cooldown_seconds | 30 |
| max_nodes | 10 |
| min_nodes | 2 |
| preferred_gpu_type | T4 |
| cost_aware | True |

Cell 11 trigger autoscaler evaluation. Vì utilization đạt 76.3%, vượt ngưỡng 70.0%, autoscaler quyết định scale up:

- Action: `SCALE_UP`
- Reason: Utilization 76.3% > threshold 70.0%
- Nodes: 7 -> 8

Sau khi scale up, 5 evaluation cycles tiếp theo đều `no_action` với utilization 66.8%, nodes giữ ở 8.

Nhận xét: autoscaling giúp cân bằng giữa performance và cost. Khi utilization quá cao, scale up giúp tránh nghẽn workload; khi utilization thấp, scale down có thể giảm idle cost.

### 2.5. Cost Analysis và Optimization

Cell 12 tạo 5 cost snapshots:

| Snapshot | Total cost | Idle cost | Waste |
|---:|---:|---:|---:|
| 1 | $0.045833 | $0.001944 | 4.2% |
| 2 | $0.045833 | $0.001944 | 4.2% |
| 3 | $0.045833 | $0.001944 | 4.2% |
| 4 | $0.045833 | $0.001944 | 4.2% |
| 5 | $0.045833 | $0.001944 | 4.2% |

Waste report tại Cell 13:

- Average waste: 4.4%
- Total idle cost: $0.019440
- Total cost: $0.440830
- Potential monthly saving: $503.88
- Severity: LOW

Cell 14 đưa ra hai khuyến nghị:

1. `USE_SPOT`: chuyển các workload fault-tolerant sang spot instances, estimated savings 65.0%.
2. `SCHEDULING`: chạy các job không khẩn cấp vào khung giờ off-peak, estimated savings 20.0%.

Nhận xét: dù waste percentage thấp, quy đổi theo tháng vẫn tạo ra potential saving đáng kể. Điều này cho thấy các khoản lãng phí nhỏ theo giờ có thể trở thành chi phí lớn ở quy mô production.

### 2.6. Visualization và Full Workflow

Notebook đã tạo biểu đồ cost breakdown và time-series cost tracking:

- `finops_cost_breakdown.png`
- `finops_timeseries.png`

Cell 18 chạy full FinOps workflow:

1. Initial cluster state: 16 GPUs, utilization 66.8%, idle 2.
2. Submit heavy workloads: utilization tăng lên 78.1%, busy 16/16.
3. Autoscaler decision: scale up vì utilization 78.1% > threshold 70.0%.
4. Cost analysis: total cost/interval $0.047778, waste 4.1%.
5. Recommendations: `USE_SPOT` và `SCHEDULING`.
6. Apply optimization: spot savings $0.0097, tương đương 70.0%.
7. Final billing: total spend $4.0920, total saved $4.2453, budget used 4.1%.

Nhận xét: quy trình này minh họa đầy đủ vòng lặp FinOps: observe -> analyze -> recommend -> optimize -> measure.

## 3. Real GPU Workload trên Kaggle

### 3.1. GPU Detection

Notebook được chạy trên Kaggle với GPU thật:

| Chỉ số | Giá trị |
|---|---|
| GPU name | Tesla T4 |
| GPU memory | 15.6 GB |
| Detected type | T4 |
| Pricing | $0.35/hour |
| CUDA | 12.8 |
| pynvml | available |

GPU metrics diagnostic tại Cell 20:

- pynvml hoạt động tốt.
- GPU util ban đầu: 0.0%.
- Memory used: 472 MB / 16106 MB.
- Power: khoảng 10.9 W.
- Temperature: 38-39 C.

Ban đầu em thử dùng P100 nhưng gặp lỗi CUDA `no kernel image is available for execution on the device`. Sau khi chuyển sang T4, workload chạy ổn định. T4 phù hợp hơn cho phần mixed precision vì có Tensor Cores.

### 3.2. FP32 Training Baseline

Cell 22 chạy ResNet-18 trên CIFAR-10 với FP32 trong 3 epoch.

| Epoch | Loss | Accuracy | Time |
|---:|---:|---:|---:|
| 1 | 1.9544 | 31.1% | 39.7s |
| 2 | 1.4353 | 47.4% | 40.8s |
| 3 | 1.1553 | 58.4% | 45.3s |

FP32 summary:

- Total time: 125.8s
- Peak memory: 0.82 GB
- Avg GPU utilization: 95.8%
- Avg power: 65.9 W
- Avg temperature: 64.5 C
- Max GPU utilization: 99.0%
- Estimated cost: $0.012234

Nhận xét: FP32 đạt utilization rất cao, chứng tỏ workload đã sử dụng GPU hiệu quả. Tuy nhiên thời gian chạy dài hơn AMP và peak memory cũng cao hơn.

### 3.3. Mixed Precision AMP Training

Cell 23 chạy cùng workload với AMP trong 3 epoch.

| Epoch | Loss | Accuracy | Time |
|---:|---:|---:|---:|
| 1 | 2.0543 | 27.4% | 22.0s |
| 2 | 1.4666 | 46.1% | 21.0s |
| 3 | 1.1737 | 57.8% | 20.3s |

AMP summary:

- Total time: 63.3s
- Peak memory: 0.60 GB
- Avg GPU utilization: 92.9%
- Avg power: 64.9 W
- Avg temperature: 77.7 C
- Max GPU utilization: 96.0%
- Estimated cost: $0.006157

Nhận xét: AMP giảm gần một nửa thời gian training so với FP32 và giảm peak memory 0.22 GB. Accuracy cuối gần tương đương FP32, nên đây là chiến lược tối ưu chi phí tốt cho T4.

### 3.4. So sánh FP32 và AMP

Cell 24 cho kết quả so sánh:

| Metric | FP32 | AMP | Improvement |
|---|---:|---:|---|
| Total time | 125.8s | 63.3s | 1.99x faster |
| Peak memory | 0.82 GB | 0.60 GB | 0.22 GB saved |
| Cost | $0.012234 | $0.006157 | $0.006078 saved |
| Cost saving | - | - | 49.7% |
| Avg GPU util | 95.8% | 92.9% | - |
| Avg power | 65.9 W | 64.9 W | - |

Extrapolated savings:

| Quy mô training | FP32 | AMP | Saving |
|---|---:|---:|---:|
| 1 day | $8.40 | $4.23 | $4.17 |
| 1 week | $58.80 | $29.59 | $29.21 |
| 1 month | $252.00 | $126.81 | $125.19 |

Nhận xét: với cùng loại GPU và cùng bài toán, mixed precision là một tối ưu có tác động trực tiếp đến chi phí vì giảm thời gian chiếm dụng GPU. Ở quy mô dài ngày hoặc nhiều experiment, phần savings cộng dồn rất đáng kể.

### 3.5. Report real GPU cost về Gateway

Cell 25 gửi kết quả real GPU workload về FinOps Gateway:

- FP32 workload cost: $0.012200, rate $0.3500/hour.
- AMP workload reported as spot: cost $0.001800, saved $0.004300.
- Project `real-gpu-lab`: total cost $0.028000.
- Total savings: $0.008600.
- Workloads: 4.
- Cost snapshot waste: 14.4%.

Final dashboard sau khi bao gồm mock và real GPU:

- Total platform cost: $4.0920.
- Total savings: $4.2453.
- Budget utilization: 4.1%.
- Alert: OK.

Notebook cũng tạo các biểu đồ real GPU:

- `real_gpu_comparison.png`
- `cost_per_epoch.png`
- `real_gpu_telemetry.png`

## 4. Advanced GPU Cost Optimization

### 4.1. Multi-GPU Cost Analysis

Cell 27 là bài tập phân tích chi phí multi-GPU. Ý tưởng chính là so sánh các cấu hình 1, 2, 4, 8 GPU dựa trên:

- Training time sau khi tính scaling factor.
- Total cost = số GPU x thời gian x đơn giá GPU.
- Cost-performance ratio.
- Scaling efficiency.

Bài học quan trọng là tăng số lượng GPU không đảm bảo giảm tổng chi phí. Nếu scaling efficiency thấp, nhiều GPU hơn có thể làm training nhanh hơn nhưng tổng chi phí lại cao hơn do overhead communication và underutilization.

### 4.2. Project Cost Forecasting

Cell 28 yêu cầu forecast chi phí theo từng phase của project với best case, expected case và worst case. Đây là cách phù hợp cho dự án AI thực tế vì chi phí training thường biến động theo:

- Số lần experiment.
- Thời gian tuning.
- Loại GPU.
- Số lượng GPU.
- Uncertainty của từng phase.

Forecast có confidence interval giúp team chủ động đặt budget buffer thay vì chỉ dùng một con số estimate cố định.

### 4.3. Optimization Opportunity Analysis

Cell 29 yêu cầu xếp hạng các cơ hội tối ưu theo savings, effort, risk và dependencies. Các chiến lược quan trọng gồm:

- Mixed precision để giảm runtime và memory.
- Spot/preemptible instance cho workload fault-tolerant.
- Autoscaling để giảm idle GPU.
- Scheduling job vào thời điểm rẻ hơn.
- Chọn GPU type phù hợp thay vì luôn dùng GPU đắt nhất.
- Checkpointing để giảm rủi ro khi dùng spot.

Trong thực tế, nên ưu tiên quick wins trước: mixed precision, scheduling và spot cho job thử nghiệm. Các thay đổi rủi ro cao như đổi GPU type hoặc thay đổi distributed training strategy cần benchmark trước.

### 4.4. Integrated Cost Dashboard

Cell 30 yêu cầu dashboard tổng hợp gồm cost curve, scaling efficiency, forecast, phase breakdown, optimization matrix và cumulative savings roadmap. Dashboard kiểu này giúp kết nối dữ liệu kỹ thuật với quyết định tài chính.

Đối với team vận hành AI, dashboard nên trả lời nhanh các câu hỏi:

- Chi phí đang tập trung ở phase nào?
- GPU nào đang tạo cost nhiều nhất?
- Workload nào có utilization thấp?
- Tối ưu nào có ROI cao nhất?
- Budget còn lại là bao nhiêu?

### 4.5. Challenge Strategy: LLM Fine-tuning

Cell 31 đưa ra scenario:

- Project: Large Language Model Fine-tuning
- Baseline: 8x A100 trong 200 giờ
- Budget: $5,000
- Deadline: 2 weeks

Baseline cost:

```text
8 GPU x 200 hours x $3.67/hour = $5,872
```

Baseline vượt budget $5,000 khoảng $872, vì vậy cần tối ưu trước khi triển khai.

Chiến lược đề xuất:

1. Chuyển từ FP32 sang mixed precision.
   - Kết quả thực nghiệm trên T4 cho thấy AMP giảm cost khoảng 49.7%.
   - Với LLM fine-tuning, mixed precision thường là lựa chọn mặc định nếu model/framework hỗ trợ.

2. Dùng checkpointing và resume.
   - Đây là điều kiện cần nếu sử dụng spot/preemptible instance.
   - Giảm rủi ro mất tiến độ khi instance bị thu hồi.

3. Dùng spot instance cho phase phù hợp.
   - Áp dụng cho experiment, hyperparameter tuning, data validation hoặc các run có thể lặp lại.
   - Với phase final training gần deadline, có thể dùng on-demand để giảm rủi ro.

4. Benchmark số lượng GPU tối ưu.
   - Không mặc định dùng 8 GPU.
   - So sánh 4, 6 và 8 A100 theo throughput và cost.
   - Chọn cấu hình có cost-performance tốt nhất, không chỉ cấu hình nhanh nhất.

5. Theo dõi utilization và budget theo phase.
   - Nếu utilization thấp, cần điều chỉnh batch size, data loader hoặc số GPU.
   - Cần alert khi cost vượt threshold hoặc khi idle GPU kéo dài.

Nếu chỉ cần giảm baseline xuống dưới budget, mức giảm tối thiểu cần đạt là:

```text
($5,872 - $5,000) / $5,872 = 14.85%
```

Vì vậy, chỉ riêng mixed precision hoặc kết hợp một phần spot instance đã đủ đưa chi phí về dưới budget, miễn là accuracy và deadline vẫn đạt yêu cầu. Chiến lược hợp lý nhất là dùng mixed precision làm baseline optimization, sau đó dùng spot có kiểm soát cho các phase ít rủi ro.

## 5. Danh sách artifacts đã tạo

### 5.1. Screenshots

Các screenshot đã được lưu trong thư mục `screenshots/`, bao gồm các cell chính từ Cell 3 đến Cell 31:

- `cell3.png`, `cell4.png`
- `cell5.png`, `cell6.png`
- `cell7,8.png`, `cell9.png`
- `cell10.png`, `cell11.png`
- `cell12,13.png`, `cell14,15.png`
- `cell16.png`, `cell17.png`, `cell18.png`
- `cell19.png` đến `cell31.png`

### 5.2. Generated charts

Các chart đã tải về trong thư mục `generated_charts/`:

- `finops_cost_breakdown.png`
- `finops_timeseries.png`
- `real_gpu_comparison.png`

Notebook output cũng ghi nhận đã tạo thêm `cost_per_epoch.png` và `real_gpu_telemetry.png`. Nếu các file này chưa nằm trong thư mục `generated_charts/`, có thể tải bổ sung từ Kaggle output panel hoặc dùng screenshot Cell 26 làm bằng chứng.

### 5.3. Notebook

Notebook đã chạy hoàn chỉnh và có output:

- `notebook/gpu_finops_lab.ipynb`

## 6. Bài học rút ra

Qua bài lab, em rút ra các bài học chính:

- GPU FinOps cần đo cả utilization, cost, waste và savings, không chỉ quan sát GPU có chạy hay không.
- GPU idle vẫn tạo chi phí, nên autoscaling và scheduling là hai kỹ thuật quan trọng.
- Spot instance giúp tiết kiệm đáng kể nhưng cần checkpointing và chấp nhận rủi ro preemption.
- Mixed precision là tối ưu rất hiệu quả trên GPU T4: trong bài lab giảm thời gian training từ 125.8s xuống 63.3s và giảm chi phí khoảng 49.7%.
- Multi-GPU scaling cần benchmark thực tế vì tốc độ tăng không tuyến tính với số lượng GPU.
- Dashboard và cost allocation giúp biến thông tin kỹ thuật thành quyết định vận hành/tài chính cụ thể.

## 7. Kết luận

Bài lab đã hoàn thành toàn bộ pipeline GPU FinOps từ local mock services đến real GPU workload trên Kaggle. Hệ thống mô phỏng được các hoạt động quan trọng trong quản trị chi phí GPU: monitoring, billing, spot pricing, autoscaling, waste analysis, visualization, real training và advanced cost planning.

Kết quả thực nghiệm cho thấy các chiến lược như mixed precision, spot instance, autoscaling và chọn cấu hình GPU phù hợp có thể giảm chi phí đáng kể mà vẫn giữ hiệu quả training. Đây là nền tảng quan trọng khi triển khai các hệ thống AI production có sử dụng GPU ở quy mô lớn.
