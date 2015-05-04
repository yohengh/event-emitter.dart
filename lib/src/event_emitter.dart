library event_emitter.event_emitter;

import 'dart:mirrors';
import './event_interface.dart';
import './event_handler_interface.dart';

typedef void EventHandlerFunction(EventInterface event);

class EventEmitter {
    Map<dynamic, List> _listeners = {};
    Map<dynamic, List> _oneTimeListeners = {};
    static int defaultMaxListeners = 10;
    int _maxListeners;

    static const String _NEW_LISTENER_EVENT_NAME = 'newListener';
    static const String _REMOVE_LISTENER_EVENT_NAME = 'removeListener';

    EventEmitter addListener(event, listener) {
        if (!_listeners.containsKey(event)) {
            _listeners[event] = [];
        }

        _verifyListenersLimit(event);
        _listeners[event].add(listener);

        emit(_NEW_LISTENER_EVENT_NAME, [event, listener]);

        return this;
    }

    EventEmitter on(event, listener) {
        return addListener(event, listener);
    }

    EventEmitter once(event, listener) {
        if (!_oneTimeListeners.containsKey(event)) {
            _oneTimeListeners[event] = [];
        }

        _verifyListenersLimit(event);
        _oneTimeListeners[event].add(listener);

        emit(_NEW_LISTENER_EVENT_NAME, [event, listener]);

        return this;
    }

    int _getMaxListeners() {
        if (_maxListeners == null) {
            return defaultMaxListeners;
        }

        return _maxListeners;
    }

    void _verifyListenersLimit(event) {
        int nextCount = ++listeners(event).length;
        int maxListeners = _getMaxListeners();

        if (nextCount >= maxListeners) {
            throw new Exception("Max listeners count for event '$event' exceeded. Current limit is set to ${_getMaxListeners()}");
        }
    }

    EventEmitter removeListener(event, listener) {
        if (_listeners.containsKey(event) && _listeners[event].contains(listener)) {
            _listeners[event].remove(listener);
            emit(_REMOVE_LISTENER_EVENT_NAME, [event, listener]);
        }

        if (_oneTimeListeners.containsKey(event) && _oneTimeListeners[event].contains(listener)) {
            _oneTimeListeners[event].remove(listener);
            emit(_REMOVE_LISTENER_EVENT_NAME, [event, listener]);
        }

        return this;
    }

    EventEmitter removeAllListeners([event]) {
        if (event == null) {
            _listeners.forEach((eventName, List handlers) {
                if (eventName != _REMOVE_LISTENER_EVENT_NAME) {
                    for (int i = 0; i < handlers.length; i++) {
                        emit(_REMOVE_LISTENER_EVENT_NAME, [eventName, handlers[i]]);
                        handlers.removeAt(i);
                    }
                }
            });
            
            _listeners.clear();
        } else{
            if (_listeners.containsKey(event) && event != _REMOVE_LISTENER_EVENT_NAME) {
                for (int i = 0; i < _listeners[event].length; i++) {
                    emit(_REMOVE_LISTENER_EVENT_NAME, [event, _listeners[event][i]]);
                    _listeners[event].removeAt(i);
                }
                
                _listeners[event].clear();
            }

            if (_oneTimeListeners.containsKey(event) && event != _REMOVE_LISTENER_EVENT_NAME) {
                for (int i = 0; i < _oneTimeListeners[event].length; i++) {
                    emit(_REMOVE_LISTENER_EVENT_NAME, [event, _oneTimeListeners[event][i]]);
                    _oneTimeListeners[event].removeAt(i);
                }
                
                _oneTimeListeners[event].clear();
            }
        }

        return this;
    }

    EventEmitter setMaxListeners(int listenersCount) {
        _maxListeners = listenersCount;

        return this;
    }

    List listeners(event) {
        List result = [];
        if (_listeners.containsKey(event)) {
            result.addAll(_listeners[event]);
        }

        if (_oneTimeListeners.containsKey(event)) {
            result.addAll(_oneTimeListeners[event]);
        }

        return result;
    }

    bool emit(event, [List params = const []]) {
        var eventType = event is EventInterface ? event.runtimeType : event;
        bool handlersFound = false;

        if (_listeners.containsKey(eventType)) {
            handlersFound = true;
            _listeners[eventType].forEach((handler) {
                _callHandler(handler, event, params);
            });
        }

        if (_oneTimeListeners.containsKey(eventType)) {
            handlersFound = true;
            for (int i = 0; i < _oneTimeListeners[eventType].length; i++) {
                var handler = _oneTimeListeners[eventType][i];
                _callHandler(handler, event, params);
                _oneTimeListeners[eventType].removeAt(i);
            }
        }

        return handlersFound;
    }

    void _callHandler(handler, [event, List params = const []]) {
        if (handler is EventHandlerFunction) {
            handler(event);
        } else if (handler is EventHandlerInterface) {
            (handler as EventHandlerInterface).execute(event);
        } else {
            Function.apply(handler, params);
        }
    }

    static int listenerCount(EventEmitter emitter, event) {
        return emitter.listeners(event).length;
    }
}
