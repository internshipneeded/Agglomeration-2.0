import torch
import torch.nn as nn
import math
from torchvision import models
from torch import Tensor
from typing import Type, Any, Callable, Union, List, Optional
try:
    from torch.hub import load_state_dict_from_url
except ImportError:
    from torch.utils.model_zoo import load_url as load_state_dict_from_url

# ==================================================================================================
# ================================ PART 1: RESNET HELPERS ==========================================
# ==================================================================================================

def conv3x3(in_planes: int, out_planes: int, stride: int = 1, groups: int = 1, dilation: int = 1) -> nn.Conv2d:
    return nn.Conv2d(in_planes, out_planes, kernel_size=3, stride=stride, padding=dilation, groups=groups, bias=False, dilation=dilation)

def conv1x1(in_planes: int, out_planes: int, stride: int = 1) -> nn.Conv2d:
    return nn.Conv2d(in_planes, out_planes, kernel_size=1, stride=stride, bias=False)

class BasicBlock(nn.Module):
    expansion: int = 1
    def __init__(self, inplanes: int, planes: int, stride: int = 1, downsample=None, groups=1, base_width=64, dilation=1, norm_layer=None):
        super().__init__()
        if norm_layer is None: norm_layer = nn.BatchNorm2d
        self.conv1 = conv3x3(inplanes, planes, stride); self.bn1 = norm_layer(planes); self.relu = nn.ReLU(inplace=True)
        self.conv2 = conv3x3(planes, planes); self.bn2 = norm_layer(planes); self.downsample = downsample; self.stride = stride
    def forward(self, x: Tensor) -> Tensor:
        identity = x
        out = self.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        if self.downsample: identity = self.downsample(x)
        out += identity; return self.relu(out)

class Bottleneck(nn.Module):
    expansion: int = 4
    def __init__(self, inplanes: int, planes: int, stride: int = 1, downsample=None, groups=1, base_width=64, dilation=1, norm_layer=None):
        super().__init__()
        if norm_layer is None: norm_layer = nn.BatchNorm2d
        width = int(planes * (base_width / 64.0)) * groups
        self.conv1 = conv1x1(inplanes, width); self.bn1 = norm_layer(width)
        self.conv2 = conv3x3(width, width, stride, groups, dilation); self.bn2 = norm_layer(width)
        self.conv3 = conv1x1(width, planes * self.expansion); self.bn3 = norm_layer(planes * self.expansion)
        self.relu = nn.ReLU(inplace=True); self.downsample = downsample; self.stride = stride
    def forward(self, x: Tensor) -> Tensor:
        identity = x
        out = self.relu(self.bn1(self.conv1(x)))
        out = self.relu(self.bn2(self.conv2(out)))
        out = self.bn3(self.conv3(out))
        if self.downsample: identity = self.downsample(x)
        out += identity; return self.relu(out)

class ResNet(nn.Module):
    def __init__(self, block, layers, num_classes=1000, zero_init_residual=False, groups=1, width_per_group=64, replace_stride_with_dilation=None, norm_layer=None):
        super().__init__()
        if norm_layer is None: norm_layer = nn.BatchNorm2d
        self._norm_layer = norm_layer; self.inplanes = 64; self.dilation = 1
        if replace_stride_with_dilation is None: replace_stride_with_dilation = [False, False, False]
        self.groups = groups; self.base_width = width_per_group
        self.conv1 = nn.Conv2d(3, self.inplanes, kernel_size=7, stride=2, padding=3, bias=False)
        self.bn1 = norm_layer(self.inplanes); self.relu = nn.ReLU(inplace=True); self.maxpool = nn.MaxPool2d(kernel_size=3, stride=2, padding=1)
        self.layer1 = self._make_layer(block, 64, layers[0])
        self.layer2 = self._make_layer(block, 128, layers[1], stride=2, dilate=replace_stride_with_dilation[0])
        self.layer3 = self._make_layer(block, 256, layers[2], stride=2, dilate=replace_stride_with_dilation[1])
        self.layer4 = self._make_layer(block, 512, layers[3], stride=2, dilate=replace_stride_with_dilation[2])
        self.avgpool = nn.AdaptiveAvgPool2d((1, 1)); self.fc = nn.Linear(512 * block.expansion, num_classes)
        for m in self.modules():
            if isinstance(m, nn.Conv2d): nn.init.kaiming_normal_(m.weight, mode="fan_out", nonlinearity="relu")
            elif isinstance(m, (nn.BatchNorm2d, nn.GroupNorm)): nn.init.constant_(m.weight, 1); nn.init.constant_(m.bias, 0)
        if zero_init_residual:
            for m in self.modules():
                if isinstance(m, Bottleneck): nn.init.constant_(m.bn3.weight, 0)
                elif isinstance(m, BasicBlock): nn.init.constant_(m.bn2.weight, 0)

    def _make_layer(self, block, planes, blocks, stride=1, dilate=False):
        norm_layer = self._norm_layer; downsample = None; previous_dilation = self.dilation
        if dilate: self.dilation *= stride; stride = 1
        if stride != 1 or self.inplanes != planes * block.expansion:
            downsample = nn.Sequential(conv1x1(self.inplanes, planes * block.expansion, stride), norm_layer(planes * block.expansion))
        layers = [block(self.inplanes, planes, stride, downsample, self.groups, self.base_width, previous_dilation, norm_layer)]
        self.inplanes = planes * block.expansion
        for _ in range(1, blocks):
            layers.append(block(self.inplanes, planes, groups=self.groups, base_width=self.base_width, dilation=self.dilation, norm_layer=norm_layer))
        return nn.Sequential(*layers)

    def forward(self, x):
        x = self.maxpool(self.relu(self.bn1(self.conv1(x))))
        x = self.layer4(self.layer3(self.layer2(self.layer1(x))))
        return self.fc(torch.flatten(self.avgpool(x), 1))

def resnet50(pretrained=False, progress=True, **kwargs):
    model = ResNet(Bottleneck, [3, 4, 6, 3], **kwargs)
    if pretrained:
        try:
             state_dict = load_state_dict_from_url("https://download.pytorch.org/models/resnet50-0676ba61.pth", progress=progress)
             model.load_state_dict(state_dict)
        except:
             pass 
    return model


# ==================================================================================================
# ============================ PART 2: TRANSFORMER & ECT_SAL =======================================
# ==================================================================================================

class Attention(nn.Module):
    def __init__(self, config):
        super(Attention, self).__init__()
        self.num_attention_heads = config["num_heads"]
        self.attention_head_size = int(config['hidden_size'] / self.num_attention_heads)
        self.all_head_size = self.num_attention_heads * self.attention_head_size
        self.query = nn.Linear(config['hidden_size'], self.all_head_size)
        self.key = nn.Linear(config['hidden_size'], self.all_head_size)
        self.value = nn.Linear(config['hidden_size'], self.all_head_size)
        self.out = nn.Linear(self.all_head_size, config['hidden_size'])
        self.attn_dropout = nn.Dropout(config["attention_dropout_rate"])
        self.proj_dropout = nn.Dropout(config["attention_dropout_rate"])
        self.softmax = nn.Softmax(dim=-1)

    def transpose_for_scores(self, x):
        new_x_shape = x.size()[:-1] + (self.num_attention_heads, self.attention_head_size)
        x = x.view(*new_x_shape)
        return x.permute(0, 2, 1, 3)

    def forward(self, hidden_states):
        mixed_query_layer = self.query(hidden_states)
        mixed_key_layer = self.key(hidden_states)
        mixed_value_layer = self.value(hidden_states)
        query_layer = self.transpose_for_scores(mixed_query_layer)
        key_layer = self.transpose_for_scores(mixed_key_layer)
        value_layer = self.transpose_for_scores(mixed_value_layer)
        attention_scores = torch.matmul(query_layer, key_layer.transpose(-1, -2))
        attention_scores = attention_scores / math.sqrt(self.attention_head_size)
        attention_probs = self.attn_dropout(self.softmax(attention_scores))
        context_layer = torch.matmul(attention_probs, value_layer)
        context_layer = context_layer.permute(0, 2, 1, 3).contiguous()
        new_context_layer_shape = context_layer.size()[:-2] + (self.all_head_size,)
        context_layer = context_layer.view(*new_context_layer_shape)
        return self.proj_dropout(self.out(context_layer))

class Mlp(nn.Module):
    def __init__(self, config):
        super(Mlp, self).__init__()
        self.fc1 = nn.Linear(config['hidden_size'], config['mlp_dim'])
        self.fc2 = nn.Linear(config['mlp_dim'], config['hidden_size'])
        self.act_fn = torch.nn.functional.gelu
        self.dropout = nn.Dropout(config['dropout_rate'])
    def forward(self, x):
        return self.dropout(self.fc2(self.dropout(self.act_fn(self.fc1(x)))))

class Block(nn.Module):
    def __init__(self, config):
        super(Block, self).__init__()
        self.attention_norm = nn.LayerNorm(config['hidden_size'], eps=1e-6)
        self.ffn_norm = nn.LayerNorm(config['hidden_size'], eps=1e-6)
        self.ffn = Mlp(config)
        self.attn = Attention(config)
    def forward(self, x):
        h = x
        x = self.attention_norm(x)
        x = self.attn(x)
        x = x + h
        h = x
        x = self.ffn_norm(x)
        x = self.ffn(x)
        x = x + h
        return x

class Encoder(nn.Module):
    def __init__(self, config):
        super(Encoder, self).__init__()
        self.layer = nn.ModuleList([Block(config) for _ in range(config["num_layers"])])
        self.encoder_norm = nn.LayerNorm(config["hidden_size"], eps=1e-6)
    def forward(self, hidden_states):
        for layer_module in self.layer:
            hidden_states = layer_module(hidden_states)
        return self.encoder_norm(hidden_states)

class TransEncoder(nn.Module):
    def __init__(self, in_channels, spatial_size, cfg):
        super(TransEncoder, self).__init__()
        self.patch_embeddings = nn.Conv2d(in_channels=in_channels, out_channels=cfg['hidden_size'], kernel_size=1, stride=1)
        self.position_embeddings = nn.Parameter(torch.zeros(1, spatial_size, cfg['hidden_size']))
        self.transformer_encoder = Encoder(cfg)
    def forward(self, x):
        a, b = x.shape[2], x.shape[3]
        x = self.patch_embeddings(x)
        x = x.flatten(2).transpose(-1, -2)
        embeddings = x + self.position_embeddings
        x = self.transformer_encoder(embeddings)
        B, n_patch, hidden = x.shape
        x = x.permute(0, 2, 1).contiguous().view(B, hidden, a, b)
        return x

cfg1 = {"hidden_size" : 768, "mlp_dim" : 768*4, "num_heads" : 1, "num_layers" : 2, "attention_dropout_rate" : 0, "dropout_rate" : 0.1}
cfg2 = {"hidden_size" : 768, "mlp_dim" : 768*4, "num_heads" : 1, "num_layers" : 2, "attention_dropout_rate" : 0.1, "dropout_rate" : 0.1}
cfg3 = {"hidden_size" : 512, "mlp_dim" : 512*4, "num_heads" : 1, "num_layers" : 1, "attention_dropout_rate" : 0.1, "dropout_rate" : 0.1}

class _Encoder(nn.Module):
    def __init__(self):
        super(_Encoder, self).__init__()
        base_model = resnet50(pretrained=True)
        base_layers = list(base_model.children())[:8]
        self.encoder = nn.ModuleList(base_layers).eval()
    def forward(self, x):
        outputs = []
        for ii,layer in enumerate(self.encoder):
            x = layer(x)
            if ii in {5,6,7}: outputs.append(x)
        return outputs

class _Decoder(nn.Module):
    def __init__(self):
        super(_Decoder, self).__init__()
        self.alpha = nn.Parameter(torch.tensor(0.5))
        self.conv1 = nn.Conv2d(768, 768, 3, 1, 1); self.batchnorm1 = nn.BatchNorm2d(768)
        self.conv2 = nn.Conv2d(768, 512, 3, 1, 1); self.batchnorm2 = nn.BatchNorm2d(512)
        self.conv3 = nn.Conv2d(512, 256, 3, 1, 1); self.batchnorm3 = nn.BatchNorm2d(256)
        self.conv4 = nn.Conv2d(256, 128, 3, 1, 1); self.batchnorm4 = nn.BatchNorm2d(128)
        self.conv5 = nn.Conv2d(128, 64, 3, 1, 1); self.batchnorm5 = nn.BatchNorm2d(64)
        self.conv6 = nn.Conv2d(64, 32, 3, 1, 1); self.batchnorm6 = nn.BatchNorm2d(32)
        self.conv7 = nn.Conv2d(32, 1, 3, 1, 1)
        self.TransEncoder1 = TransEncoder(in_channels=2048, spatial_size=8*8, cfg=cfg1)
        self.TransEncoder2 = TransEncoder(in_channels=1024, spatial_size=16*16, cfg=cfg2)
        self.TransEncoder3 = TransEncoder(in_channels=512, spatial_size=32*32, cfg=cfg3)
        self.add = torch.add; self.relu = nn.ReLU(True); self.upsample = nn.Upsample(scale_factor=2, mode='nearest'); self.sigmoid = nn.Sigmoid()

    def forward(self, x , y ):
        x3, x4, x5 = x; y3 , y4 , y5 = y
        x5 = self.TransEncoder1(x5); y5 = self.TransEncoder1(y5)
        x5 = self.alpha*x5 + (1-self.alpha)*y5 
        x5 = self.upsample(self.relu(self.batchnorm1(self.conv1(x5))))
        x4_a = self.TransEncoder2(x4); y4 = self.TransEncoder2(y4)
        x4_a = self.alpha*x4_a + (1-self.alpha)*y4 
        x4 = self.upsample(self.relu(self.batchnorm2(self.conv2(self.relu(x5 * x4_a)))))
        x3_a = self.TransEncoder3(x3); y3 = self.TransEncoder3(y3)
        x3_a = self.alpha*x3_a + (1-self.alpha)*y3
        x3 = self.upsample(self.relu(self.batchnorm3(self.conv3(self.relu(x4 * x3_a)))))
        x2 = self.relu(self.batchnorm5(self.conv5(self.upsample(self.relu(self.batchnorm4(self.conv4(x3)))))))
        x1 = self.conv7(self.relu(self.batchnorm6(self.conv6(self.upsample(x2)))))
        return self.sigmoid(x1)

class ECT_SAL(nn.Module):
    def __init__(self):
        super(ECT_SAL, self).__init__()
        self.encoder = _Encoder()
        self.decoder = _Decoder()
    def forward(self, x , y):
        x = self.encoder(x); y = self.encoder(y)
        x = self.decoder(x , y)
        return x

class TwoStreamEfficientNet(nn.Module):
    def __init__(self, num_classes):
        super(TwoStreamEfficientNet, self).__init__()
        self.backbone = models.efficientnet_b2(weights=models.EfficientNet_B2_Weights.DEFAULT)
        num_features = self.backbone.classifier[1].in_features
        self.backbone.classifier = nn.Identity()
        self.classifier = nn.Sequential(nn.Dropout(p=0.3), nn.Linear(num_features * 2, num_classes))

    def forward(self, yolo_input, saliency_input):
        feat1 = self.backbone(yolo_input)
        feat2 = self.backbone(saliency_input)
        combined = torch.cat((feat1, feat2), dim=1)
        return self.classifier(combined)
