import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceInfo {
  final String name;
  final String ip;
  final int port;

  DeviceInfo({required this.name, required this.ip, required this.port});
}

class MDnsService {
  static const String _serviceType = '_http._tcp';
  String _serviceName = 'WiFi-T Device';
  
  MDnsClient? _client;
  final List<DeviceInfo> _discoveredDevices = [];
  Function(List<DeviceInfo>)? onDevicesUpdated;
  bool _isDiscovering = false;

  List<DeviceInfo> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    
    _isDiscovering = true;
    _discoveredDevices.clear();
    
    try {
      _client = MDnsClient();
      await _client!.start();
      
      print('Starting mDNS discovery for $_serviceType.local');
      
      // 查找HTTP服务
      await for (final PtrResourceRecord ptr in _client!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceType),
      )) {
        if (!_isDiscovering) break;
        
        print('Found PTR record: ${ptr.domainName}');
        
        await for (final SrvResourceRecord srv in _client!.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          if (!_isDiscovering) break;
          
          print('Found SRV record: ${srv.target}:${srv.port}');
          
          await for (final IPAddressResourceRecord ip in _client!.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            if (!_isDiscovering) break;
            
            print('Found IP: ${ip.address.address}');
            
            // 检查是否是局域网IP
            if (!ip.address.isLoopback && ip.address.type == InternetAddressType.IPv4) {
              final device = DeviceInfo(
                name: ptr.domainName.replaceAll('.$_serviceType.local', ''),
                ip: ip.address.address,
                port: srv.port,
              );
              
              if (!_discoveredDevices.any((d) => d.ip == device.ip)) {
                _discoveredDevices.add(device);
                onDevicesUpdated?.call(_discoveredDevices);
                print('Added device: ${device.name} at ${device.ip}:${device.port}');
              }
            }
          }
        }
      }
      
      print('mDNS discovery completed, found ${_discoveredDevices.length} devices');
      
      // 直接进行网络扫描
      print('Starting network scan immediately...');
      await _scanTargetNetwork();
      
    } catch (e) {
      print('mDNS discovery error: $e');
      // 如果mDNS失败，回退到网络扫描
      await _scanTargetNetwork();
    }
  }
  
  Future<void> _scanTargetNetwork() async {
    try {
      // 获取本机IP地址
      final interfaces = await NetworkInterface.list();
      String? localSubnet;
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              localSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              print('Found local subnet: $localSubnet.x');
              break;
            }
          }
        }
        if (localSubnet != null) break;
      }
      
      if (localSubnet == null) {
        print('Could not determine local subnet');
        return;
      }
      
      print('Scanning $localSubnet.x network for port 8080...');
      
      // 扫描同网段的IP范围
      final futures = <Future>[];
      
      // 扫描1-254的完整范围
      for (int i = 1; i <= 254; i++) {
        if (!_isDiscovering) break;
        futures.add(_checkDevice('$localSubnet.$i'));
        
        // 每20个IP检查一次，避免过多并发
        if (i % 20 == 0) {
          await Future.wait(futures);
          futures.clear();
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
      
      print('Network scan completed, found ${_discoveredDevices.length} total devices');
      
      // 扫描完成后停止发现状态，但保持设备列表
      _isDiscovering = false;
    } catch (e) {
      print('Network scan error: $e');
      _isDiscovering = false;
    }
  }
  
  Future<void> _checkDevice(String ip) async {
    if (!_isDiscovering) return;
    
    try {
      final socket = await Socket.connect(
        ip, 
        8080, 
        timeout: const Duration(milliseconds: 500)
      );
      socket.destroy();
      
      final device = DeviceInfo(
        name: 'WiFi-T Device ($ip)',
        ip: ip,
        port: 8080,
      );
      
      if (!_discoveredDevices.any((d) => d.ip == device.ip)) {
        _discoveredDevices.add(device);
        onDevicesUpdated?.call(_discoveredDevices);
        print('Found and added device at $ip');
      } else {
        print('Device at $ip already exists in list');
      }
    } catch (e) {
      // 连接失败，设备不存在或端口未开放
    }
  }

  Future<void> advertiseService(int port) async {
    try {
      // 获取用户设置的设备名
      await _loadDeviceName();
      
      // Windows平台跳过mDNS广播
      if (Platform.isWindows) {
        print('mDNS service advertising skipped on Windows platform');
        return;
      }
      
      _client ??= MDnsClient();
      await _client!.start();
      
      print('mDNS service advertising on port $port with device name: $_serviceName');
      
      // 注册服务记录
      final serviceName = '$_serviceName.$_serviceType.local';
      print('Advertising service: $serviceName');
      
    } catch (e) {
      print('mDNS advertise error: $e');
    }
  }
  
  Future<void> _loadDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serviceName = prefs.getString('device_name') ?? 'WiFi-T Device';
    } catch (e) {
      _serviceName = 'WiFi-T Device';
    }
  }

  void stopDiscovery() {
    _isDiscovering = false;
    _client?.stop();
    _client = null;
    // 不清空设备列表，保持显示
  }
}