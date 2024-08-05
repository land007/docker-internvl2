FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

MAINTAINER Yiqiu Jia <yiqiujia@hotmail.com>

RUN echo $(date "+%Y-%m-%d_%H:%M:%S") >> /.image_times && \
    echo $(date "+%Y-%m-%d_%H:%M:%S") > /.image_time && \
    echo "land007/speech-socket" >> /.image_names && \
    echo "land007/speech-socket" > /.image_name

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libgl1-mesa-glx wget bzip2 git && \
    apt-get clean

# 创建 Miniconda 目录
RUN mkdir -p /opt/miniconda3

# 下载 Miniconda 安装脚本
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /opt/miniconda3/miniconda.sh

# 运行 Miniconda 安装脚本
RUN bash /opt/miniconda3/miniconda.sh -b -u -p /opt/miniconda3

# 删除安装脚本
RUN rm -rf /opt/miniconda3/miniconda.sh

# 添加 Miniconda 到 PATH 环境变量中
ENV PATH=/opt/miniconda3/bin:$PATH

# 验证 conda 是否安装成功
RUN conda --version

# 创建 conda 环境
RUN conda create -n internvl python=3.9 -y

# 创建目标目录
RUN mkdir -p /workspace/public/transformers

# 克隆 InternVL 仓库
RUN git clone https://github.com/OpenGVLab/InternVL.git /workspace/public/transformers/InternVL

# 安装 requirements.txt
RUN /opt/miniconda3/envs/internvl/bin/pip install -r /workspace/public/transformers/InternVL/requirements.txt

# 安装 streamlit_demo.txt
RUN /opt/miniconda3/envs/internvl/bin/pip install -r /workspace/public/transformers/InternVL/requirements/streamlit_demo.txt

# 更新 huggingface_hub
RUN /opt/miniconda3/envs/internvl/bin/pip install -U huggingface_hub

# 下载模型
RUN /opt/miniconda3/envs/internvl/bin/huggingface-cli download --resume-download --local-dir-use-symlinks False OpenGVLab/InternVL2-4B --local-dir /workspace/public/transformers/InternVL2-4B

# 设置环境变量
ENV SD_SERVER_PORT=39999
ENV WEB_SERVER_PORT=10003
ENV CONTROLLER_PORT=40000
ENV CONTROLLER_URL=http://0.0.0.0:$CONTROLLER_PORT
ENV SD_WORKER_URL=http://0.0.0.0:$SD_SERVER_PORT

RUN apt-get install -y --no-install-recommends libglib2.0-dev
RUN mkdir /workspace/public/transformers/InternVL/streamlit_demo/logs

# 启动 streamlit 应用
CMD cd /workspace/public/transformers/InternVL/streamlit_demo && \
    /opt/miniconda3/envs/internvl/bin/streamlit run app.py --server.port $WEB_SERVER_PORT -- --controller_url $CONTROLLER_URL --sd_worker_url $SD_WORKER_URL & \
    sleep 2 && \
    /opt/miniconda3/envs/internvl/bin/python /workspace/public/transformers/InternVL/streamlit_demo/controller.py --host 0.0.0.0 --port $CONTROLLER_PORT & \
    sleep 2 && \
    CUDA_VISIBLE_DEVICES=0 /opt/miniconda3/envs/internvl/bin/python /workspace/public/transformers/InternVL/streamlit_demo/model_worker.py --host 0.0.0.0 --controller $CONTROLLER_URL --port 40003 --worker http://0.0.0.0:40003 --model-path /workspace/public/transformers/InternVL2-4B
#    cd /workspace/public/transformers/InternVL/streamlit_demo && CUDA_VISIBLE_DEVICES=0 /opt/miniconda3/envs/internvl/bin/python model_worker.py --host 0.0.0.0 --controller http://0.0.0.0:40000 --port 40003 --worker http://0.0.0.0:40003 --model-path /workspace/public/transformers/InternVL2-4B
#docker build -t land007/internvl2:latest .
