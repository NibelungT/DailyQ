# Pigeon 生成的 ProxyApi 用 suspend 函数跨 channel 通信，方法签名里带
# kotlin.coroutines.Continuation。R8 混淆会把该类型改名（如 Ls4;），
# 而调用方按 Lkotlin/coroutines/Continuation; 解析，运行期抛 NoSuchMethodError：
#   no non-static method "Lio/flutter/plugins/sharedpreferences/
#   SharedPreferencesApiRegistrar;.getAll(...Lkotlin/coroutines/Continuation;)..."
# 后果是 shared_preferences 整体不可用，所有写入静默丢失。
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# 保住协程接口与状态机的原始名字，避免签名被改写
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.CoroutineContext { *; }
-keep class kotlin.coroutines.jvm.internal.** { *; }
-keepclassmembers class kotlin.coroutines.jvm.internal.BaseContinuationImpl {
    <methods>;
}
-dontwarn kotlin.coroutines.**
